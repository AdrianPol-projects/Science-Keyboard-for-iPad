# Science Keyboard for iPad

An over-the-top science keyboard for iPad (and iPhone). It looks like the iOS 18 system keyboard and adds every scientific symbol Unicode has, a periodic table, step-by-step notation builders, a calculator, clipboard history and more.

It is a **custom keyboard extension** inside a **container app**, written in SwiftUI. It needs iOS 17 or later.

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

### Panels
These are in the top bar, and the `ƒ` key toggles to the last one you used.

| Panel | What's inside |
|---|---|
| ★ Recents | Favorites (long-press any symbol to add one) and recently used symbols |
| αβ Greek | Upper/lowercase, variants, bold/italic Greek, full Greek blocks |
| ± Math | Operators, relations, sets, logic, brackets, fractions, geometry, function names, plus every math Unicode block |
| ∫ Calculus | Integrals, ∂/∇, series, transforms |
| → Arrows | Common arrows, harpoons/equilibria, all arrow blocks |
| x² Super/Sub | Every super/subscript character, plus **x² / x₂ typing modes** |
| x⃗ Accents | Combining marks (vector, hat, bar, dot…) |
| 𝔸 Styles | 13 math alphabets (𝐛𝐨𝐥𝐝, 𝑖𝑡𝑎𝑙𝑖𝑐, 𝓈𝒸𝓇𝒾𝓅𝓉, 𝔣𝔯𝔞𝔨𝔱𝔲𝔯, 𝕕𝕠𝕦𝕓𝕝𝕖…) as typing modes or applied to a word |
| ⚗︎ Chemistry | Tap-to-insert **periodic table**, an element action bar (name, nuclide, configuration, molar mass…), reaction arrows, charges, states, particles, common species, alchemical symbols, chemistry builders |
| ⚛︎ Physics | 32 physical constants (tap for the symbol, `=` for the full value), units and SI prefixes, quantum/vector/EM symbols, physics builders |
| ✦ Builders | 50+ step-by-step presets, plus any you create in the app |
| 📋 Clipboard | History with pinning; save the clipboard; copy / cut / paste the selection |
| ❝ Snippets | Reusable formulas (edit them in the app) |
| 🧮 Tools | Scientific **calculator** (constants, DEG/RAD, inserts the result or `expr = result`), **converters** for the selection, last word or line, **Unicode hex input**, and **cursor tools** |
| ℝ Letters, ◆ Shapes, U+ All Unicode | Letterlike symbols, unit squares, shapes, dingbats and 48 complete Unicode blocks |

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
- **Builders**: run and edit presets.
- **Snippets** and **Clipboard history**.
- **Converter**: LaTeX, chemistry, units, scripts, math alphabets and combining marks.
- **Calculator**.
- **Settings**: haptics, clicks, flick mode, theme, accent, height, clipboard size and more.

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
  Presets.swift          Builder engine + built-in library
  SymbolCatalog.swift    Symbol categories, Unicode blocks, physics data, search index
Keyboard/                The keyboard extension (UIInputViewController + SwiftUI)
App/                     The container app
.github/workflows/       CI build on macOS runners
```
