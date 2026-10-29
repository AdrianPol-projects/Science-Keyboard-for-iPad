# Science Notes

Science Notes is [FSNotes](https://github.com/glushchenko/fsnotes) for iPad with a toolkit for science students added on top.

FSNotes is by Oleksandr Glushchenko and is MIT-licensed. Its license is kept in [`LICENSE`](LICENSE). The upstream code was imported unmodified from commit `c01b1d54a7a5c5552245370da91e3dfbc47085bd`.

Everything FSNotes already does still works:
- Markdown notes stored as plain files
- folders and tags
- `[[wiki links]]`
- MathJax, Mermaid and code highlighting in preview
- encryption
- Git backups

## What was added

Open the toolkit with the **⊞** button in the note's navigation bar. Three buttons on the keyboard toolbar (✏️ sketch, scan, ƒ calculator) open a tool directly; a fourth (⊞) opens the full toolkit.

| Group | Tools |
|---|---|
| Capture | **Sketch & handwriting**: PencilKit with plain, lined, grid or dotted paper; finger or Pencil-only input; inserted as an image. **Scan document**: camera scan, pages as images and/or recognized text. **Text from photo**: OCR in English and Czech. **Read aloud**: several voices, adjustable speed. |
| Science | **Calculator**: functions and constants; insert the result or the whole equation. **Solve “=” lines**: fills in every line of the note that ends with `=`. **Molar mass**: e.g. `M(H₂O) = 2·1.008 + 15.999 = 18.015 g·mol⁻¹`. **Periodic table**. **Symbols**. **Physical constants**. **Unit converter**: 11 quantities. **Graph plotter**: up to 4 functions, inserted as an image. **Notation builders**: nuclides, decays, integrals… **Convert**: LaTeX → Unicode, chemistry, units, math styles. |
| Study | **Statistics**: words, reading time, top words, to-do progress. **Outline**: jump to headings and insert a table of contents. **Flashcards**: built from `term :: definition` and `Q:`/`A:` lines. **Focus timer**: Pomodoro that logs sessions to the note. |
| Writing | **Templates**: lecture, Cornell, lab report, chemistry/physics problem, revision, meeting, journal, weekly plan, paper summary. **Find & replace**: regex, whole words, match case. **Line tools**: sort, dedupe, number, checklist, case… **Table builder**: also converts CSV to a table. **Random & date**: dice, coin, passwords, UUID, lorem ipsum, countdowns, Czech dates. **QR code**. **Export**: PDF, Markdown, plain text, print. |

## Where the code is

FSNotes itself is barely touched, so new upstream versions can be merged easily:
- **New code**: `FSNotes iOS/ScienceNotes/`
  - `SNToolkit.swift`: bridge to the editor, tool list, presentation
  - `SNCaptureTools.swift`
  - `SNScienceTools.swift`
  - `SNStudyTools.swift`
  - `SNWritingTools.swift`
- **Shared science engine**: `../Shared/*.swift`, referenced from the Xcode project so the keyboard and the notes app use one copy.
- **Changes to upstream files**:
  - `EditorViewController.swift`: three insertions marked `Science Notes`, which add the toolbar and navigation-bar buttons.
  - `project.pbxproj`: the new files, plus bundle IDs `com.adrianpol.ScienceNotes` and `com.adrianpol.ScienceNotes.Share`.
  - `Info.plist` for the app and the Share extension: display name *Science Notes*.

## Building

`.github/workflows/notes.yml` builds the app unsigned on a `macos-26` runner with the newest Xcode, because FSNotes uses iOS 26 APIs. It uploads **ScienceNotes-unsigned.ipa**. The app needs **iPadOS 18 or later**.

When you re-sign it for sideloading, iCloud entitlements are usually dropped. Notes are then stored locally in the app's Documents folder, which you can reach in the Files app. To sync, use FSNotes' Git backup, or open an external folder.
