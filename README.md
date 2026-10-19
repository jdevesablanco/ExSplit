# ExSplit

**Turn an exercise PDF into one with a single exercise per sheet — with room to solve it — straight from the right-click menu.**

[Español](README.es.md) · macOS 13+ · Apple Silicon & Intel · MIT licence · no network, no accounts

Handouts usually cram 3–6 exercises on a page. On an iPad (Goodnotes, Notability…) or on paper you want **one exercise per sheet, original content untouched (vector, selectable text), blank space below**. ExSplit finds where each exercise starts, cuts it out of the original PDF and lays it on a fresh sheet, stitching together exercises that run over a page break.

- Right-click a PDF → **Quick Actions**, **Services** or **Open With**.
- A tiny **menu bar app** to tweak behaviour, or no icon at all — your choice, asked on first run.
- Fine-tune everything: label text & position (any of 6 spots), paper, margins, ruled/grid/dotted answer area, what happens to the original (move it to `Documents/ExSplit`, Trash, or leave it), file naming…
- **Undo** the last split with one click.
- Scanned PDFs work too (macOS Vision OCR, on-device).
- Free software, **no dependencies**: pure Swift on Apple's PDFKit / CoreGraphics / Vision (no PyMuPDF/AGPL, no Python).

## Install

**Homebrew** (builds locally with the Xcode Command Line Tools — no Gatekeeper warning):

```bash
brew install jdevesablanco/tap/exsplit
exsplit install        # copies ExSplit.app to ~/Applications and opens the first-run setup
```

**Installer (.pkg)** — no Terminal needed: download `ExSplit-x.y.z.pkg` from [Releases](https://github.com/jdevesablanco/ExSplit/releases), double-click and follow the steps. It installs into *Applications* and opens the first-run setup. The first time macOS may say it can't verify the developer: right-click the file → *Open*, or *System Settings → Privacy & Security → Open Anyway* (not notarized; that needs a paid Apple Developer account).

**DMG**: download `ExSplit-x.y.z.dmg` from [Releases](https://github.com/jdevesablanco/ExSplit/releases), drag the app to *Applications*.
The app is ad-hoc signed, not notarized by Apple, so the first time: *System Settings → Privacy & Security → Open Anyway*.
Or skip the dialog: `xattr -dr com.apple.quarantine /Applications/ExSplit.app`.
(Notarizing needs a paid Apple Developer account; see [docs/NOTARIZATION.md](docs/NOTARIZATION.md).)

**From source**: `git clone … && cd ExSplit && Scripts/build-app.sh && open build/ExSplit.app`

## First run

A short welcome asks how you want your sheets (label position, answer area, what to do with the original), whether ExSplit should live in the **menu bar** (recommended: change the essentials or undo in one click) or stay invisible, and which right-click entries to install.

Without the menu bar icon the app doesn't stay open. To change settings later: open ExSplit from Spotlight/Launchpad, or **hold ⌥ (Option)** when you run the action to pick options just for that run.

## Using it

| Where | How |
|---|---|
| Quick Actions / Services *(recommended)* | Right-click a PDF → *Quick Actions* → **Split exercises with ExSplit** (installed from the app) |
| Open With | Right-click → *Open With* → ExSplit |
| Menu bar | *Split PDF…*, quick toggles, *Undo last split* |
| Terminal | `exsplit split file.pdf [options]` |

Hold **⌥** on any of them to choose options for that run only.

## Command line

```bash
exsplit split worksheet.pdf                  # uses your saved settings
exsplit split *.pdf --original keep --suffix " (split)" --answer grid
exsplit generate in.pdf out.pdf --label "Problem {n}" --label-pos topRight --paper letter
exsplit analyze worksheet.pdf                # just count exercises
exsplit undo                                 # undo the last split
exsplit selftest                             # engine smoke test (synthetic PDF)
```

Automate it: a [Hazel](https://www.noodlesoft.com/) rule or a Finder *Folder Action* that runs `exsplit split "$1"` on new PDFs.

## How it works

1. Reads text with positions (PDFKit, or Vision OCR for scans) and looks for the best `1.`, `1)`, `Exercise 1`, `Problem 1`… sequence 1…N (or your own regex).
2. Ignores repeating headers/footers/page numbers; finds where content ends using a low-res ink map.
3. Cuts each exercise from its marker to the next, joins the pieces that cross pages, and draws them (vector, via `CGContext.drawPDFPage` with clipping) on a new sheet with your label and answer area.
4. Writes to a temporary file first, checks it, and only then moves the original — nothing is lost, and every split can be undone.

Settings live in `~/Library/Application Support/ExSplit/settings.json`.

## Limitations

- Needs numbered exercises. Unnumbered or multi-column layouts: use *Settings → Detection → custom pattern*, or it will say so instead of guessing.
- A shared statement before exercise 1 is not copied into each sheet.
- Exercises longer than one sheet continue on a second sheet at full size (flagged *to review*).

## Privacy

Everything runs on your Mac. No telemetry, no network access.

## License

MIT © 2026 Julio Devesa Blanco
