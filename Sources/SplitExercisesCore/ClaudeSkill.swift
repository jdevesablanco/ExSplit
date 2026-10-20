import Foundation

/// Skill de Claude que enseña a usar la CLI de SplitExercises. Fuente única: este texto se instala en Claude Code
/// (`~/.claude/skills`). Vive en el binario para que la CLI y la app nunca se desincronicen. (La app de Claude usa el servidor MCP.)
public enum ClaudeSkill {
    public static let folderName = "splitexercises"

    static let template = #"""
    ---
    name: splitexercises
    description: Split exercise PDFs into one exercise per sheet with the SplitExercises macOS app (command line). Use when the user asks to split / divide / separate the exercises of a PDF, or of all the exercise PDFs in a folder ("divide los ejercicios de esta carpeta", "un ejercicio por hoja", "split these exercises"), on a Mac that has SplitExercises installed.
    ---

    # SplitExercises

    SplitExercises turns an exercise PDF into one with a single exercise per sheet, with room to solve it. It has a command line that applies the settings the user already chose in the app (paper, label, answer area, what happens to the original, file naming). **The command does everything: do not move, rename or edit files yourself and do not pass options unless the user asks.**

    ## Command

    Use `splitexercises`. If the shell says "command not found", use the full path:

    ```
    "{{CLI}}"
    ```

    | Goal | Command |
    |---|---|
    | Split one or more PDFs | `splitexercises split "a.pdf" "b.pdf"` |
    | Split every exercise PDF in a folder | `splitexercises split "/path/to/folder"` (add `--recursive` to include subfolders) |
    | Only look, change nothing | `splitexercises analyze "/path/to/folder" --json` |
    | Undo the last split | `splitexercises undo` |
    | Show the user's settings | `splitexercises settings` |

    Add `--json` to `split` or `analyze` for machine-readable output (`status`: `split`, `skipped`, `failed`, `analyzed`).

    ## How to work

    1. Run `split` directly on the path the user gave you (a file, several files, or the folder they mention). If they say "this folder", use the current or connected folder. You do not need to open or read the PDFs first.
    2. On a folder, the command itself decides which PDFs are exercise sheets: it skips PDFs without recognisable exercises, results of earlier splits and the originals folder. Do not try to guess this yourself.
    3. Report briefly: how many PDFs were split (and how many exercises), where the results are, and which were skipped or failed and why.
    4. If the user wants to review before changing anything, run `analyze` first and show what `split` would process.
    5. Only add options (`--original keep|trash|move`, `--answer lines|grid|dots|blank`, `--paper a4|letter|a5|same`, `--suffix " (x)"`, `--no-label`) when the user explicitly asks for that run. They override the saved settings for that run only.

    ## Good to know

    - By default the original PDF is moved to `Documents/SplitExercises` and the result keeps its name; the user chose that in the app. `splitexercises undo` reverts the last split.
    - The first time, macOS may ask permission to access Documents / Desktop / Downloads. Tell the user to accept and run the command again.
    - Everything runs on the user's Mac; nothing is uploaded.
    - If SplitExercises is not installed: `brew install --cask jdevesablanco/tap/splitexercises` (or the installer from https://github.com/jdevesablanco/SplitExercises/releases), then open the app once.
    """#

    /// El texto sin la sangría que usa el literal del código.
    static func dedent(_ s: String) -> String {
        let lines = s.components(separatedBy: "\n")
        let indent = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.prefix { $0 == " " }.count }.min() ?? 0
        return lines.map { $0.count >= indent ? String($0.dropFirst(indent)) : $0 }.joined(separator: "\n") + "\n"
    }

    public static func markdown(cliPath: String) -> String { dedent(template).replacingOccurrences(of: "{{CLI}}", with: cliPath) }

    /// Ruta de la CLI para escribirla en el skill y en la config de Claude. Si la que se está usando está dentro de una app
    /// (`….app/Contents/Resources/splitexercises`) se respeta: es la versión que acaba de arrancar y que sabe todo lo nuevo.
    /// Si no (CLI suelta, enlace de brew…) se prefiere la copia instalada en /Applications.
    public static func stableCLIPath(current: String) -> String {
        if current.contains(".app/Contents/Resources/") { return current }
        let fm = FileManager.default
        let candidates = ["/Applications/SplitExercises.app/Contents/Resources/splitexercises",
                          fm.homeDirectoryForCurrentUser.path + "/Applications/SplitExercises.app/Contents/Resources/splitexercises"]
        return candidates.first { fm.isExecutableFile(atPath: $0) } ?? current
    }

    // MARK: Claude Code

    public static var claudeCodeSkillDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/skills/\(folderName)", isDirectory: true)
    }
    public static var installedInClaudeCode: Bool {
        FileManager.default.fileExists(atPath: claudeCodeSkillDir.appendingPathComponent("SKILL.md").path)
    }

    /// Instala (o actualiza) el skill para Claude Code. Funciona en cualquier sesión nueva, sin pasos manuales.
    @discardableResult
    public static func installForClaudeCode(cliPath: String) throws -> URL {
        let dir = claudeCodeSkillDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("SKILL.md")
        try markdown(cliPath: cliPath).write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    public static func uninstallFromClaudeCode() {
        try? FileManager.default.removeItem(at: claudeCodeSkillDir)
    }
}
