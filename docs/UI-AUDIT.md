# Throw — UI audit against Bloomee, Musify, LocalSend

Audit date: 2026-11-24 · Commit baseline: `b4201f1` (v1.0.15) · Flutter 3.50.1

References studied:

| App | What it gets right | Repo |
|---|---|---|
| **LocalSend** | The domain benchmark. Selection-first flow (pick devices → pick payload → send), explicit connection state per device, big target controls, progress that survives a screen you are not looking at. | `localsend/localsend` |
| **Bloomee** | Strong content hierarchy — one tinted hero, distinct surface ramps, shape language that separates "player" from "list". | `HemantKArya/BloomeeTunes` |
| **Musify** | Adaptive shell (rail ↔ bar via `LayoutBuilder`), consistent card geometry, settings that persist. | `gokadzev/Musify` |
| **planets** (ResoCoder) | Teaching-grade widget composition and hero transitions. Repo no longer public; studied from the published article/pattern (implicit routes + `Hero` on a two-pane layout). | — |

---

## Findings, ordered by severity

### P0 — shipped bug: the entire palette has zero alpha

`lib/core/theme.dart` declares every token as `Color(0x0A1214)` etc. — that is an
**8-digit ARGB literal with alpha = `0x0A`… no: alpha digit is the first pair
after `0x`, so `0x0A1214` has only six digits.** A six-digit literal is
`0x00RRGGBB`: alpha = 0, fully transparent.

Measured (test output, `#AARRGGBB`):

```
bg            -> #000a1214  alpha=0
surface       -> #00101a1d  alpha=0
surfaceHigh   -> #00162226  alpha=0
border        -> #0033474d  alpha=0
text          -> #00dee7e9  alpha=0
secondary     -> #008fa0a4  alpha=0
accent        -> #000e6a64  alpha=0
onAccent      -> #00f3fbfa  alpha=0
accentText    -> #005fbfb4  alpha=0
light*        -> #00……      alpha=0
```

Consequences on a real device:

* `scaffoldBackgroundColor` is transparent → the window default (white) shows
  through, while `onSurface` text is a translucent tint → **near-invisible white
  text on white**.
* `Card`, `NavigationBar`, `SnackBar`, buttons: all transparent fills, borders
  invisible.
* Every colour-math test in `test/theme_and_errors_test.dart` passes because
  `luminance()` ignores alpha — the suite has never caught this.
* The committed "screenshots" in `assets/screenshots/` are raw test renders on a
  white canvas with tofu glyphs: the app has been visually broken since the
  moss/deep-water palette was introduced (`3529798`), and the screenshot
  workflow that should have exposed it fails (see CI below).

### P1 — CI/screenshot pipeline is not telling the truth

* `test/screenshots_test.dart` only diffs when `THROW_COMPARE_SCREENSHOTS` is
  defined; the file is otherwise a smoke test. Renders use the test default
  font (tofu boxes) because bundled fonts are never loaded via `FontLoader`.
* `screenshots.yml` **runs on `ubuntu-latest`** — host that produced the white
  tofu renders — while CD builds `windows-latest`. Jobs fail ("Update
  Screenshots" red on `main`), and the last good `home.png` predates the
  palette change.
* `cd.yml` uses `flutter-version: '3.x'` while CI uses the same — a silent
  moving target; a Flutter release can change golden rasterisation without a
  commit.

### P1 — the app cannot show what it received

`TransferProvider.receivedPayloads` is populated and **rendered nowhere**.
Received text and files are unreachable: no copy, no open, no history surface.
`open_file` is declared for exactly this and never called. This is the single
biggest functional gap versus LocalSend, whose receive flow is the product.

### P1 — Home makes the device a dropdown

`DropdownButtonFormField<DeviceModel>` is the only way to pick a target. On a
sharing app the *peer* is the first-class object (LocalSend: per-device cards
with live state; Android's own share sheet: peer tiles). A dropdown hides every
peer but one, hides connection state, and collides with the `DeviceModel`
`==`/hashCode contract (identity by `id`) inside a form field. With 0–1
connected devices it also spends 72dp to say nothing.

### P2 — localization rot (67 keys, 7 hardcoded strings)

Hardcoded English shipped in the UI:

* `discover_screen.dart:63–64` — the two scanning subtitles, the most-read
  strings on that screen.
* `home_screen.dart:142` — "Send files and text directly to nearby devices."
* `home_screen.dart:219` — `tooltip: 'Clear'`.
* `settings_screen.dart:171` — "Manage your device, language, and appearance."

Plus a wrong key: the Transfers empty state says **`stateNoDevices`** ("No
devices nearby yet.") when there are no *transfers* — visible wrong copy.

### P2 — settings do not persist

`LocaleProvider` lives in memory only. Language and theme reset on every
launch. Musify and Bloomee both persist theirs; a toggle that does not survive
restart teaches the user it is broken.

### P2 — declared dependencies that are not used

`flutter_animate`, `animations`, `lottie`, `flutter_slidable`,
`flutter_adaptive_scaffold`, `window_manager`, `flutter_window_close` are in
`pubspec.yaml` and imported nowhere. They inflate build time, trip
dependabot and supply-chain surface, and misrepresent the stack.

### P3 — duplicated layout with no shared vocabulary

Each screen re-implements its own header row (logo 32 + title + subtitle),
empty state (centre icon + text), and card. The rebuild is where the
`safeArea`/20dp padding decisions drift apart. LocalSend centralises
`BigButton`, `DeviceBadge`, progress widgets.

### P3 — the nav rail never uses the theme it defines

`theme.dart` ships `navigationRailTheme` for both brightnesses; `AdaptiveNav`
overrides `backgroundColor` inline and never sets indentation/label behaviour,
so the rail is the only surface that ignores the design tokens.

### P3 — version drift is unguarded

`AppConstants.appVersion = '1.0.15'` duplicates `pubspec.yaml` `version:`.
Nothing fails if they diverge; `_isNewerVersion` is private inside a screen
widget and therefore untested.

---

## What this pass changes

See `CHANGELOG.md` → `[Unreleased]` and the commits on `ui/audit-pass`.
Every finding above except the reference-only ones gets a fix **and a test**.
