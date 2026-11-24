# Changelog

All notable changes to Throw are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] — 2026-11-24

Everything below came from using the built app and reporting what broke. The
common thread: the previous round made the UI *look* right, but several flows
had no answer at the end of them — a file arrived and you could not find it, a
phone appeared and you could not tell which one it was, a transfer ran and it
never said how fast.

### Fixed — transfer rows broke on narrow screens

`TransferProgressTile` laid its bottom line out as a `Row` with
`mainAxisAlignment: spaceBetween` and two unbounded `Text`s. At 320–360 dp the
peer string and the "12.4 MB / 51.1 MB" counter together exceeded the row, the
Row overflowed, and its children painted outside the card — the "name or size
goes outside the box" report.

The row is rebuilt as a flat list row: the title is inside an `Expanded` with
ellipsis, the counters sit in a `Wrap` so they break to a second line instead of
painting out of bounds, and the trailing slot is capped at 40% of the width.
`test/transfer_row_test.dart` renders it at 320, 360 and 411 dp with a
200-character file name and asserts no overflow.

### Added — transfer speed and time remaining

`AppUtils.formatSpeed` existed and was never called; `TransferModel` had no
rate at all. `TransferRateTracker` (`core/transfer_stats.dart`) keeps an
exponentially smoothed bytes/second over a short window and an ETA, with an
injectable clock. It clamps negative byte counts (a transport that restarts a
payload used to be able to produce a negative speed), folds samples taken under
250 ms instead of dividing by ~0, and refuses to show an ETA longer than twelve
hours.

Active rows show `2.4 MB/s · 25 s left`. Finished rows show the average over the
whole transfer, which is the number that means something once it is over.

### Fixed — the other phone showed "Throw", not the device name

Two independent causes:

1. `DeviceProvider` resolved the real device name in an async constructor task
   while `startAdvertising` could run first, so the advertisement carried the
   placeholder. Advertising and discovery now await the name, and renaming a
   device while visible re-advertises under the new name immediately.
2. BLE cannot tell the receiver anything about the sender's name before a
   connection exists. Peers are now named by a HELLO frame sent on connect and
   by a `from` field carried on every payload, and a name learned that way is
   never overwritten by a later nameless discovery event.

Any peer that still has no name is rendered as `Nearby device · A1B2` — the
last four hex characters of its address — instead of a 36-character UUID.

### Fixed — "received, but saved where?"

Both services wrote into `getApplicationDocumentsDirectory()`. On Android that
is `/data/user/0/<package>/app_flutter`: a directory no file manager can open
without root. Files arrived, the list said "received", and there was no route to
the file.

`IncomingStore` now probes for a folder the user can actually reach — public
`Downloads/Throw` first, then an external-storage root, then the app folder as a
last resort — and only announces one it has written a probe file into. Every
receipt states its folder and offers open / copy-location, the Transfers list
shows the folder on finished rows, and the empty state names the folder before
anything has arrived, so the answer exists in advance.

A second file with the same name is saved as `IMG_0001 (1).jpg` rather than
silently replacing the first.

### Added — send to several devices at once

Selection was a single nullable device. Home now selects any number of
connected devices and `TransferProvider.sendTextTo` / `sendFileTo` fan out, one
transfer per device, so each has its own progress and its own failure. One
unreachable phone reports on its own row and does not abort the other two.

A device that has just connected is selected automatically, because connecting
is the reason someone opened the screen; an explicit untick is remembered and
respected.

### Changed — the boxes are actually gone

1.1 replaced bordered cards with a rounded *filled* rectangle per section —
better, but still a rectangle drawn around content, and every section had one.
`PanelGroup` is now `Section`: an uppercase label, the rows, and a hairline
between them, on the bare canvas. No fill, no radius, no border. The only filled
shapes left are pills that are genuinely pressable and the progress track, which
is a gauge rather than a container.

Coincidentally this is also how the references do it: LocalSend's tiles are
flush on the canvas, Musify's settings are divider-separated runs.

### Added — About, developer and links

A real About screen: version and build, what the app is, the developer and their
location, and working links to GitHub, the website, the source, releases, the
issue tracker and the MIT licence. Every URL resolves; no handles were invented.

The old "About" row's subtitle repeated the version printed one row above it.
That is gone.

### Fixed — the send controls read as two competing buttons

Text sending had a "Send" button and the row below it had a "Pick" button; at
narrow widths the two labels wrapped to two lines inside a fixed `Row`. The
composer and its primary action are now one unit, and "Send files" is a single
icon+label control with the whole row to itself, so nothing can be squeezed.

### Fixed — a separate "Received" tab nobody could find

Received items now appear directly under the send area on Home with the folder
they landed in, and the full history lives on one screen. Needing to know that a
second tab existed in order to find a file was the actual bug.

---

## [1.1.0] — 2026-11-24

### Changed — the UI no longer looks like a dashboard of boxes

The first pass of this audit shipped correct, but it corrected *within* the
card stack: a header band, then three bordered 28dp cards per screen. Every
section was a rectangle on a rectangle, which is the generic widget-kit look
the reference apps avoid.

What changed, and what it was compared against:

- **The app icon is gone from inside the app.** It sat on all five headers
  (Home, Discover, Transfers, Settings) and two of them drew a filled band
  behind it. A logo repeated on every screen adds nothing over the window
  chrome — neither LocalSend nor Musify does it.
- **No more card-per-idea.** Grouping now comes from one tinted surface per
  section with hairline separators (Musify's flush `CustomBar` runs,
  LocalSend's `margin: EdgeInsets.zero` tiles). New `PanelGroup` + `FlatRow`
  replace five stacked cards. Settings went from two bordered cards to two
  flush groups; Home from four cards to one.
- **No more nested boxes.** Home's header band held the peer picker which held
  a form field. The band is gone; the composer is a soft writing area inside
  the panel instead of a filled pill that read as a button.
- **One send path.** The composer and the "Send" row below it were the same
  action twice; the row is now the button that belongs to the composer.
- **Transfers empty state is typographic**, not a circled glyph on a card.
- **Surface ramp instead of outlines.** `containerLow` / `containerHigh` /
  `raised` plus a `hairline` separator, all measured: every text token clears
  AA on all three (muted ink 4.52–6.23:1).

### Added — motion

- `Pressable`: press-down scale on every actionable control, built on
  `Listener` so it never competes with a button's own gestures.
- `Entrance` / `StaggeredEntrance`: sections fade and lift in with a 45 ms
  stagger, ported from LocalSend's `InitialFadeTransition`.
- Peer pills animate between selected and unselected states and slide their
  check in rather than popping (`AnimatedContainer` + `AnimatedSize`).
- Device rows carry an animated connection dot; Discover shows a real spinner
  while scanning, and visibility is a switch that states the current
  condition instead of a button that reads "Make visible" forever.
- Transfer progress animates to its new value instead of jumping in BLE-sized
  steps, and its glyph reflects status.
- Every duration collapses to zero when the OS asks for reduced motion.

### Fixed

- A peer pill lost its 48dp touch target in the redesign: an
  `AnimatedContainer` with `alignment` set fills the incoming constraints, so
  a lone pill became a full-width button. Pinned by tests for intrinsic width,
  shared row, and 48dp height.
- `Pressable` silently never fired on content that does not paint an opaque
  box; it now hit-tests `translucent`.
- The composer's hint duplicated the row below it and wrapped mid-sentence.
- A duplicate version string in the About row.
- `AppConstants.appVersion` is now checked against `pubspec.yaml` in CI.

### Tests

107 total (was 88). Every new widget has behaviour tests, including the two
layout regressions above and reduced-motion handling.

## [1.0.10]

- Change Android/Linux application ID to `com.mahimmazidul.throwapp` (namespace, applicationId, MainActivity package).

## [1.0.9]

- Fix Android release build by enforcing compileSdk 37 across app/plugins and consolidating Gradle config.
- Fix Bluetooth file sharing: add framed transfer protocol with file metadata, reassembly, and disk save on receive.
- Add Android share-sheet intake (SEND/SEND_MULTIPLE) via receive_sharing_intent, with pending shared-items UI in Home.
- Stabilize screenshot smoke test to avoid CI flakiness from late font/system callbacks.

## [1.0.8]

- Restore the Android app label resource and align the app version with the release tag.
- Update payload tests and run screenshot rendering as a smoke test in CI.

## [Unreleased]

### Added

- Project scaffolding: pubspec, localization config, lint rules
- CI, CD, and Pages workflows
- Issue templates, PR template, dependabot, CODEOWNERS
- Community docs
- App logo and social preview
- GitHub Pages landing page with FAQ, responsive and zero-JS
- Soothing blue-slate palette for web and app theme
- Responsive breakpoints and app constants
- Material 3 theme with bundled Hind Siliguri (dark first, light ready)
- English and Bengali localization strings
- App entry point with offline-safe font loading
- Icon, splash, and MSIX packaging configuration
- Android manifest (share sheet included, no INTERNET permission), ProGuard
  rules, and release signing config
- Device, payload, transfer, and connection-request models
- Permission flow for nearby devices and Bluetooth
- Abstract transfer service and platform factory
- Nearby service for Android (WiFi Direct via nearby_connections)
