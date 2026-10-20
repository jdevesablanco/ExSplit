# SplitExercises

**Turn an exercise PDF into one with a single exercise per sheet — with room to solve it — straight from the right-click menu.**

[Español](README.es.md) · macOS 13+ · Apple Silicon & Intel · MIT licence · no network, no accounts

Handouts usually cram 3–6 exercises on a page. On an iPad (Goodnotes, Notability…) or on paper you want **one exercise per sheet, original content untouched (vector, selectable text), blank space below**. SplitExercises finds where each exercise starts, cuts it out of the original PDF and lays it on a fresh sheet, stitching together exercises that run over a page break.

- Right-click a PDF → **Quick Actions**, **Services** or **Open With** — or just ask **Claude** to split a folder.
- A tiny **menu bar app** to tweak behaviour, or no icon at all — your choice, asked on first run.
- Fine-tune everything: label text & position (any of 6 spots), paper, margins, ruled/grid/dotted answer area, what happens to the original (move it to `Documents/SplitExercises`, Trash, or leave it), file naming…
- **Undo** the last split with one click.
- Scanned PDFs work too (macOS Vision OCR, on-device).
- Free software, **no dependencies**: pure Swift on Apple's PDFKit / CoreGraphics / Vision (no PyMuPDF/AGPL, no Python).

## Install

**Homebrew (recommended)**:

```bash
brew install --cask jdevesablanco/tap/splitexercises
```

Installs SplitExercises into *Applications* (and the `splitexercises` command). Open it once to run the first-run setup.

**Homebrew, built from source** (compiles locally with the Xcode Command Line Tools — no Gatekeeper warning):

```bash
brew install jdevesablanco/tap/splitexercises
splitexercises install        # copies SplitExercises.app to /Applications and opens the first-run setup
```

**Installer (.pkg)** — no Terminal needed: download `SplitExercises-x.y.z.pkg` from [Releases](https://github.com/jdevesablanco/SplitExercises/releases), double-click and follow the steps. It installs into *Applications* and opens the first-run setup. The first time macOS may say it can't verify the developer: right-click the file → *Open*, or *System Settings → Privacy & Security → Open Anyway* (not notarized; that needs a paid Apple Developer account).

**DMG**: download `SplitExercises-x.y.z.dmg` from [Releases](https://github.com/jdevesablanco/SplitExercises/releases), drag the app to *Applications*.
The app is ad-hoc signed, not notarized by Apple, so the first time: *System Settings → Privacy & Security → Open Anyway*.
Or skip the dialog: `xattr -dr com.apple.quarantine /Applications/SplitExercises.app`.
(Notarizing needs a paid Apple Developer account; see [docs/NOTARIZATION.md](docs/NOTARIZATION.md).)

**From source**: `git clone … && cd SplitExercises && Scripts/build-app.sh && open build/SplitExercises.app`

## First run

A short welcome asks how you want your sheets (label position, answer area, what to do with the original), whether SplitExercises should live in the **menu bar** (recommended: change the essentials or undo in one click) or stay invisible, and which right-click entries to install.

Without the menu bar icon the app doesn't stay open. To change settings later: open SplitExercises from Spotlight/Launchpad, or **hold ⌥ (Option)** when you run the action to pick options just for that run.

## Using it

| Where | How |
|---|---|
| Quick Actions / Services *(recommended)* | Right-click a PDF → *Quick Actions* → **SplitExercises** (installed from the app) |
| Open With | Right-click → *Open With* → SplitExercises |
| Menu bar | *Split PDF…*, quick toggles, *Undo last split* |
| Claude / AI assistants | Ask *“split the exercises in this folder”* — see [With Claude](#with-claude-and-other-ai-assistants) |
| Terminal | `splitexercises split file.pdf [options]` |

Hold **⌥** on any of them to choose options for that run only.

## Command line

```bash
splitexercises split worksheet.pdf                  # uses your saved settings
splitexercises split ~/Documents/Course/Unit3       # a whole folder: only touches PDFs that are exercise sheets
splitexercises split ~/Documents/Course -r          # …including subfolders
splitexercises split *.pdf --original keep --suffix " (split)" --answer grid
splitexercises generate in.pdf out.pdf --label "Problem {n}" --label-pos topRight --paper letter
splitexercises analyze worksheet.pdf                # just count exercises
splitexercises analyze ~/Documents/Course --json    # what `split` would process, machine-readable
splitexercises undo                                 # undo the last split
splitexercises selftest                             # engine smoke test (synthetic PDF)
```

On a folder, `split` skips PDFs without recognisable exercises (fewer than 2), results of earlier splits and the originals folder, and carries on if one file fails. `--json` prints a machine-readable report (`split`, `skipped`, `failed`).

Automate it: a [Hazel](https://www.noodlesoft.com/) rule or a Finder *Folder Action* that runs `splitexercises split "$1"` on new PDFs.

## With Claude (and other AI assistants)

SplitExercises ships a small **skill** that teaches Claude one thing: to run `splitexercises split` on whatever you point it at. The command applies the settings you chose in the app, so the assistant never moves or renames files itself.

- **Claude Code**: the first-run setup (or *Settings → Finder → With Claude*) installs the skill with one click into `~/.claude/skills/splitexercises`. Or run `splitexercises install-skill`.
- **Claude app (chat / Cowork)**: skills are uploaded once. Run `splitexercises install-skill --zip` (or use the button in the app), then *Settings → Capabilities → Skills → Upload skill* and pick `SplitExercises-skill.zip`.
- **Any other assistant with shell access on your Mac**: tell it to use `splitexercises split <file or folder>` (see `splitexercises --help`). Assistants without access to your computer (plain web chat) can't run it.

Then ask, for example: *“split all the exercises in this folder”*. Claude runs the command; the command decides which PDFs are exercise sheets and applies your settings. Undo with `splitexercises undo`.

## How it works

1. Reads text with positions (PDFKit, or Vision OCR for scans) and looks for the best `1.`, `1)`, `Exercise 1`, `Problem 1`… sequence 1…N (or your own regex).
2. Ignores repeating headers/footers/page numbers; finds where content ends using a low-res ink map.
3. Cuts each exercise from its marker to the next, joins the pieces that cross pages, and draws them (vector, via `CGContext.drawPDFPage` with clipping) on a new sheet with your label and answer area.
4. Writes to a temporary file first, checks it, and only then moves the original — nothing is lost, and every split can be undone.

Settings live in `~/Library/Application Support/SplitExercises/settings.json`.

## Limitations

- Needs numbered exercises. Unnumbered or multi-column layouts: use *Settings → Detection → custom pattern*, or it will say so instead of guessing.
- A shared statement before exercise 1 is not copied into each sheet.
- Exercises longer than one sheet continue on a second sheet at full size (flagged *to review*).

## Privacy

Everything runs on your Mac. No telemetry, no network access.

## License

MIT © 2026 Julio Devesa Blanco
