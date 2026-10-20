import Foundation
import CoreGraphics
import CoreText

/// Prueba de humo sin archivos externos: genera un PDF de ejercicios sintético (cabecera, número de página, ejercicios que
/// cruzan de página, una figura), lo divide y comprueba el resultado. La usan la CI y `brew test`.
public enum SelfTest {
    public static func run() -> (ok: Bool, log: String) {
        var log = ""
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("splitexercises-selftest-\(UUID().uuidString.prefix(6))")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        let src = dir.appendingPathComponent("sintetico.pdf"), out = dir.appendingPathComponent("salida.pdf")
        let expected = 12
        guard makeFixture(at: src, exercises: expected) else { return (false, "no se pudo generar el PDF de prueba") }
        do {
            var s = Settings()
            s.ocr = .never
            let r = try Splitter.generate(src, to: out, settings: s)
            if let keep = ProcessInfo.processInfo.environment["SPLITEXERCISES_KEEP_FIXTURE"] { // dev: capturas del README
                try? fm.createDirectory(atPath: keep, withIntermediateDirectories: true)
                try? fm.copyItem(at: src, to: URL(fileURLWithPath: keep).appendingPathComponent("before.pdf"))
                try? fm.copyItem(at: out, to: URL(fileURLWithPath: keep).appendingPathComponent("after.pdf"))
            }
            log += "ejercicios detectados: \(r.exerciseCount) (esperados \(expected)); páginas \(r.sourcePages) → \(r.outputPages)\n"
            guard r.exerciseCount == expected else { return (false, log + "FALLO: número de ejercicios") }
            guard r.outputPages == expected else { return (false, log + "FALLO: cada ejercicio debía ocupar una hoja") }
            let multi = r.rows.filter { $0.sourcePages.count > 1 }.count
            log += "ejercicios que cruzan de página unidos: \(multi)\n"
            guard multi >= 1 else { return (false, log + "FALLO: no se unieron los ejercicios partidos") }
            // y el flujo completo con el original
            let work = dir.appendingPathComponent("work.pdf")
            try fm.copyItem(at: src, to: work)
            var s2 = s; s2.originalAction = .moveToFolder
            let o = try Splitter.split(work, settings: s2)
            guard fm.fileExists(atPath: o.resultURL.path), let od = o.originalURL, fm.fileExists(atPath: od.path) else {
                return (false, log + "FALLO: no se movió el original")
            }
            try Splitter.undo(o.historyID)
            guard fm.fileExists(atPath: work.path) else { return (false, log + "FALLO: deshacer no restauró el original") }
            log += "dividir + original + deshacer: OK\n"
            // carpetas: divide la hoja de ejercicios, y al repetir no vuelve a dividir su propio resultado
            let folder = dir.appendingPathComponent("carpeta", isDirectory: true)
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try fm.copyItem(at: src, to: folder.appendingPathComponent("tema1.pdf"))
            var s3 = s; s3.originalAction = .keep
            let first = Batch.split([folder.path], recursive: false, settings: s3)
            guard first.filter({ $0.status == .split }).count == 1 else { return (false, log + "FALLO: la carpeta no se dividió") }
            let again = Batch.split([folder.path], recursive: false, settings: s3)
            let splitAgain = again.filter { $0.status == .split }.count
            try? Splitter.undo()
            guard splitAgain == 0 else { return (false, log + "FALLO: volvió a dividir un resultado") }
            log += "carpeta: divide una vez y no repite: OK\n"
            return (true, log + "OK")
        } catch {
            return (false, log + "FALLO: \(error.localizedDescription)")
        }
    }

    static func makeFixture(at url: URL, exercises: Int) -> Bool {
        var box = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { return false }
        let H = Double(box.height)
        let font = CTFontCreateWithName("Helvetica" as CFString, 11, nil)
        func text(_ s: String, x: Double, top: Double, size: CGFloat = 11) {
            let f = CTFontCreateWithName("Helvetica" as CFString, size, nil)
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: CGColor(gray: 0, alpha: 1)]))
            ctx.textPosition = CGPoint(x: x, y: H - top - Double(size))
            CTLineDraw(line, ctx)
        }
        _ = font
        var page = 0
        func begin() {
            if page > 0 { ctx.endPDFPage() }
            ctx.beginPDFPage(nil); page += 1
            text("Curso de prueba · Hoja de ejercicios", x: 72, top: 36, size: 9)
            ctx.setStrokeColor(CGColor(gray: 0, alpha: 1)); ctx.setLineWidth(0.5)
            ctx.move(to: CGPoint(x: 72, y: H - 52)); ctx.addLine(to: CGPoint(x: 523, y: H - 52)); ctx.strokePath()
            text("\(page)", x: 290, top: 800, size: 9)
        }
        begin()
        var y = 90.0
        let bottom = 770.0
        text("Ejercicios del Tema 1", x: 72, top: y, size: 16); y += 40
        for n in 1...exercises {
            let lines = 3 + (n % 4) + (n == 5 ? 8 : 0)
            let need = Double(lines) * 15 + (n == 5 ? 90 : 0) + 24
            _ = need
            func ensure(_ h: Double) { if y + h > bottom { begin(); y = 70 } }
            ensure(15)
            text("\(n). Enunciado del ejercicio número \(n): calcule la media y la varianza de la muestra dada.", x: 72, top: y); y += 15
            for l in 1..<lines {
                ensure(15)
                text("    línea \(l) del enunciado con más detalles y apartados para resolver el problema.", x: 72, top: y); y += 15
                if n == 5 && l == 3 {
                    ensure(90)
                    ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0.7, alpha: 1)); ctx.setLineWidth(1)
                    ctx.stroke(CGRect(x: 140, y: H - (y + 80), width: 300, height: 80)); y += 90
                }
            }
            y += 16
        }
        ctx.endPDFPage(); ctx.closePDF()
        return true
    }
}
