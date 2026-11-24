# Changelog

All notable changes to Throw are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
