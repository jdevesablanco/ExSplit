#!/usr/bin/env swift
// Genera AppIcon.icns: hoja partida en dos por una línea de corte. Uso: swift Scripts/make-icon.swift Resources/AppIcon.icns
import AppKit
import CoreGraphics

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(px) / 1024
    ctx.scaleBy(x: s, y: s)

    // fondo: squircle con degradado
    let bg = CGPath(roundedRect: CGRect(x: 40, y: 40, width: 944, height: 944), cornerWidth: 215, cornerHeight: 215, transform: nil)
    ctx.saveGState(); ctx.addPath(bg); ctx.clip()
    let cs = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: cs, colors: [CGColor(red: 0.28, green: 0.36, blue: 0.95, alpha: 1), CGColor(red: 0.47, green: 0.27, blue: 0.86, alpha: 1)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 100, y: 1000), end: CGPoint(x: 900, y: 40), options: [])
    ctx.restoreGState()

    func page(yOffset: CGFloat, topHalf: Bool) {
        // media hoja (la de arriba y la de abajo, separadas por el corte)
        let r = topHalf ? CGRect(x: 262, y: 520 + yOffset, width: 500, height: 262) : CGRect(x: 262, y: 242 + yOffset, width: 500, height: 262)
        let path = CGMutablePath()
        let rad: CGFloat = 36
        if topHalf {
            path.move(to: CGPoint(x: r.minX, y: r.minY)); path.addLine(to: CGPoint(x: r.minX, y: r.maxY - rad))
            path.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX + rad, y: r.maxY), radius: rad)
            path.addLine(to: CGPoint(x: r.maxX - rad, y: r.maxY))
            path.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.maxX, y: r.maxY - rad), radius: rad)
            path.addLine(to: CGPoint(x: r.maxX, y: r.minY)); path.closeSubpath()
        } else {
            path.move(to: CGPoint(x: r.minX, y: r.maxY)); path.addLine(to: CGPoint(x: r.minX, y: r.minY + rad))
            path.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.minX + rad, y: r.minY), radius: rad)
            path.addLine(to: CGPoint(x: r.maxX - rad, y: r.minY))
            path.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY + rad), radius: rad)
            path.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); path.closeSubpath()
        }
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.25))
        ctx.setFillColor(CGColor(gray: 1, alpha: 1)); ctx.addPath(path); ctx.fillPath()
        ctx.restoreGState()
        // líneas de texto
        ctx.setFillColor(CGColor(red: 0.35, green: 0.40, blue: 0.75, alpha: 0.55))
        let bars: [(CGFloat, CGFloat)] = topHalf ? [(0.78, 0), (0.62, 1), (0.70, 2)] : [(0.74, 0), (0.55, 1), (0.66, 2)]
        for (w, i) in bars {
            let y = (topHalf ? r.maxY - 70 : r.maxY - 52) - i * 52
            ctx.addPath(CGPath(roundedRect: CGRect(x: r.minX + 44, y: y, width: (r.width - 88) * w, height: 22), cornerWidth: 11, cornerHeight: 11, transform: nil)); ctx.fillPath()
        }
    }
    page(yOffset: 30, topHalf: true)
    page(yOffset: -30, topHalf: false)

    // línea de corte discontinua
    ctx.setStrokeColor(CGColor(red: 1, green: 0.84, blue: 0.25, alpha: 1))
    ctx.setLineWidth(18); ctx.setLineCap(.round); ctx.setLineDash(phase: 0, lengths: [1, 40])
    ctx.move(to: CGPoint(x: 150, y: 512)); ctx.addLine(to: CGPoint(x: 874, y: 512)); ctx.strokePath()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns"
let set = (out as NSString).deletingLastPathComponent + "/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: set)
try! FileManager.default.createDirectory(atPath: set, withIntermediateDirectories: true)
let sizes: [(String, Int)] = [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256),
                               ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)]
for (n, px) in sizes { try! render(px).write(to: URL(fileURLWithPath: "\(set)/icon_\(n).png")) }
let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil"); p.arguments = ["-c", "icns", set, "-o", out]
try! p.run(); p.waitUntilExit()
try? FileManager.default.removeItem(atPath: set)
print("OK", out)
