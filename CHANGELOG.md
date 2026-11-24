# Changelog

All notable changes to Throw are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
