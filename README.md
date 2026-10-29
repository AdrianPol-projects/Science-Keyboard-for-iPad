# Science Keyboard for iPad

An over-the-top science keyboard for iPad (and iPhone). It looks like the iOS 18 system keyboard and adds every scientific symbol Unicode has, a periodic table, step-by-step notation builders, a calculator, clipboard history and more.

It is a **custom keyboard extension** inside a **container app**, written in SwiftUI. It needs iOS 17 or later.

This repository also contains **Science Notes**, an iPad notes app built on the open-source [FSNotes](https://github.com/glushchenko/fsnotes) (MIT). It adds sketching, scanning with OCR, a calculator, molar mass, graphs, flashcards, a focus timer, templates and more. See [`Notes/SCIENCE_NOTES.md`](Notes/SCIENCE_NOTES.md). The **Build Notes app** workflow produces `ScienceNotes-unsigned.ipa`.

## Features

### Keyboard
- **iOS 18-style layout** with iPad and iPhone variants, light/dark mode, key shadows, iPhone key pop-ups, shift / caps lock (double-tap), auto-capitalization, and the double-space "." shortcut.
- **iPad flick keys**: swipe down on a key for its grey secondary character. You can pick numbers and punctuation, or Greek.
- **Long-press alternates** on letters, numbers and punctuation, e.g. `d → ∂ δ Δ ∇`, `= → ≠ ≈ ≡ ≤ ≥`, `2 → ² ₂ ⅔`.
- **Space-bar trackpad** to move the cursor, and **delete-repeat** that switches to deleting whole words.
- **Smart suggestion bar**: after you type something, a tap converts the word before the cursor:
  - `H2SO4 → H₂SO₄`, `Fe3+ → Fe³⁺`, `SO4^2- → SO₄²⁻`
  - `\alpha → α`, `x^2 → x²`, `m/s2 → m/s²`
  - `6.022e23 → 6.022 × 10²³`, `3/4 → ¾`, `U+2207 → ∇`, `-> → →`, `<=> → ⇌`
- **Search every symbol by name** with 🔍 (over 7,000 characters, using their real Unicode names and LaTeX aliases).

### Autocorrect (English or Czech)
- Pick **English**, **Čeština** or **Off** in the app's Settings, or tap the **EN/CZ** chip in the keyboard.
- It uses the dictionaries built into iOS (`UITextChecker`) plus your own iOS text replacements. The bold suggestion is applied when you press space or punctuation, and backspace right after it undoes the correction.
- Short words such as element symbols (Fe, Na), acronyms and words with digits are never corrected.
- With Czech on, `ě š č ř ž ý á í é ů ň ť ď` come first in the long-press menus. There's an optional **QWERTZ** layout (automatic for Czech).

### Panels
The ⊞ button in the suggestion bar (or the `ƒ` key) opens the panels. Each panel has tabs.

| Panel | Tabs |
|---|---|
| ★ Favorites | Favorites (long-press any symbol to add one) and recently used symbols |
| ∑ Symbols | Greek · Math · Calculus · Arrows · Super/Sub (with x² / x₂ typing modes) · Accents · Styles (13 math alphabets) · Letters · Shapes · All Unicode (48 blocks) |
| ⚗︎ Chemistry | **Periodic table** (tap to type, plus an element action bar) · **Molar mass** calculator · Symbols · Builders |
| ⚛︎ Physics | 32 constants (tap for the symbol, `=` for the full value) · Units · Symbols · Builders |
| = Calculator | Scientific calculator: **Paste result**, **Paste equation** (`2+3 = 5`), **Paste ×10ⁿ**, or load the current line with **From text** |
| 📋 Clipboard | **History**: tap an item to select it, then **Paste**, Pin or Delete. Also copy / cut / paste the selection · **Snippets** |
| ✦ Builders | 53 step-by-step presets plus your own |
| ⚙︎ Tools | Converters (selection, last word or line) · Unicode hex input · Cursor tools |

### Molar mass calculator
To build a formula, either:
- tap elements on the periodic table and numbers, brackets and `·` on the keypad, or
- type it with ⌨︎. Capitals are guessed (`h2so4 → H2SO4`, `nacl → NaCl`).

**From text** takes the formula before the cursor.

Choose:
- **M** (g·mol⁻¹ or g/mol), **m** (u) or **Mᵣ**
- precise, 1-decimal or whole-number atomic masses
- the step style `2·1`, `2×1` or `2(1)`

Then paste any of:
- `18.015`
- `18.015 g·mol⁻¹`
- `M(H₂O) = 18.015 g·mol⁻¹`
- `M(H₂O) = 2·1.008 + 15.999 = 18.015 g·mol⁻¹`
- the full working with `2·M(H) + M(O)`

With whole numbers and the `2(1)` style you get `M(H₂O) = 2(1) + 16 = 18 g·mol⁻¹`. Brackets, hydrates (`CuSO4·5H2O`) and charges are understood. The same calculator is in the app under **Molar mass**.

### Builders (presets)
Builders fill in a notation one step at a time. The nuclide builder works like this:

1. Pick **U** on the periodic table.
2. Confirm the proton number. **Z = 92** is pre-filled.
3. Confirm the mass number. **A = 238** is pre-filled.
4. Optionally add a charge.
5. You get **²³⁸₉₂U**.

Other built-in builders include α, β⁻, β⁺, electron-capture and γ decay equations (the daughter nuclide is computed for you), ions, formulas, reactions, equilibria, electron configurations, pH, enthalpy, scientific notation, vectors, bra-kets, fractions, integrals, sums, limits, derivatives, matrices, binomials and quadratic roots.

You can make your own in the app (**Builders → +**) with a small template language. Each token is `{expression}` or `{expression:modifier}`, for example:

```
{A:sup}{Z:sub}{el} → {A-4:sup}{Z-2:sub}{sym(Z-2)} + ⁴₂He
```

The app's **Help & syntax** screen lists every function and modifier.

### Container app
- **Get started**: setup guide and App Group status.
- **Playground**: a text area to try the keyboard.
- **Symbol browser**: search and copy symbols, and manage favorites.
- **Periodic table**: element details with copyable notations.
- **Molar mass**: the same calculator as the keyboard, with composition by mass.
- **Builders**: run and edit presets.
- **Snippets** and **Clipboard history**.
- **Converter**: LaTeX, chemistry, units, scripts, math alphabets and combining marks.
- **Calculator**.
- **Settings**: language and autocorrect, letter layout, haptics, clicks, flick mode, theme, accent, height, clipboard size and more.

## Building on GitHub's Macs

Every push runs `.github/workflows/build.yml` on a `macos-15` runner. The workflow:

1. Installs [XcodeGen](https://github.com/yonaskolb/XcodeGen) and generates `ScienceKeyboard.xcodeproj` from `project.yml`.
2. Builds for `generic/platform=iOS` without code signing.
3. Uploads **`ScienceKeyboard-unsigned`** (an `.ipa`) and **`build-log`** as artifacts.

To download the app: go to **Actions**, open the latest run, and download the **ScienceKeyboard-unsigned** artifact. Unzip it to get the `.ipa`.

## Installing (sideloading)

The IPA contains two bundles that both need signing: the app and `PlugIns/Keyboard.appex`.

### Option A: a sideloading tool
Use a re-signer that handles app extensions, such as Sideloadly, AltStore, or an on-device signer with your `.p12` + `.mobileprovision`. Load the unsigned IPA, then sign it with your certificate.

- Use your own bundle ID, e.g. `com.yourname.ScienceKeyboard`. The extension's ID must start with the app's ID (`….ScienceKeyboard.Keyboard`).
- If the tool doesn't add the **App Group** entitlement, everything still works on its own. The only difference is that snippets, settings and builders made in the app won't reach the keyboard. The app's **Get started** screen shows whether sharing is active.

### Option B: signed builds in CI
Add these repository secrets (Settings → Secrets and variables → Actions). The workflow will then also produce **`ScienceKeyboard-signed`**:

| Secret | Value |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | `base64 -i cert.p12` of your development or ad-hoc certificate |
| `P12_PASSWORD` | Password of that `.p12` |
| `BUNDLE_ID_PREFIX` | e.g. `com.yourname`. Gives `com.yourname.ScienceKeyboard` and `com.yourname.ScienceKeyboard.Keyboard` |
| `APP_PROFILE_BASE64` | Base64 of the provisioning profile for `<prefix>.ScienceKeyboard` |
| `KEYBOARD_PROFILE_BASE64` | Base64 of the provisioning profile for `<prefix>.ScienceKeyboard.Keyboard` |

Before creating the profiles, register both App IDs in the Apple Developer portal. Give both the **App Groups** capability with the group `group.<prefix>.ScienceKeyboard`, and include your iPad's UDID in the profiles. Then install the signed IPA with Apple Configurator, Finder, or `xcrun devicectl device install app`.

> The signing step re-signs the built app with `codesign`, using the entitlements from your profiles. It runs only when the secrets exist. It has not been run in this repository yet, so expect to adjust it on the first try.

### Option C: Xcode on a Mac
```
brew install xcodegen
xcodegen generate
open ScienceKeyboard.xcodeproj
```
Set your Team and `BUNDLE_ID_PREFIX` in the project build settings, then run on your iPad.

## Enabling the keyboard
Go to **Settings → General → Keyboard → Keyboards → Add New Keyboard… → Science Keyboard**. Then tap it and turn on **Allow Full Access**, which is needed for clipboard history, paste and haptics. The keyboard makes no network requests.

## Limits of iOS keyboards
These limits come from Apple and can't be worked around:
- Custom keyboards are **hidden while a hardware keyboard is attached** (Magic Keyboard / Smart Keyboard).
- Custom keyboards are not used in password or phone-number fields, or in apps that disallow third-party keyboards.
- Output is **plain Unicode text**. Super/subscripts exist only for some characters: all digits and most lowercase letters, but e.g. no subscript `b`, `c`, `d`, `f`, `g`.
- Memory is limited (around 60 MB), so the keyboard renders natively and doesn't use web views.

## Project layout
```
project.yml              XcodeGen spec (app + keyboard extension)
Config/                  Info.plists and entitlements
Shared/                  Code compiled into both targets
  Models.swift           Settings, clipboard/snippet models, App Group store
  TextTransforms.swift   Super/subscripts, math alphabets, combining marks, number formatting
  Elements.swift         118 elements, table layout, electron configurations
  Expression.swift       Calculator / template expression evaluator
  Converters.swift       Chemistry formatter, LaTeX → Unicode
  MolarMass.swift        Formula parser and molar-mass report with worked steps
  Presets.swift          Builder engine + built-in library
  SymbolCatalog.swift    Symbol categories, Unicode blocks, physics data, search index
Keyboard/                The keyboard extension (UIInputViewController + SwiftUI)
App/                     The container app
.github/workflows/       CI build on macOS runners
```
