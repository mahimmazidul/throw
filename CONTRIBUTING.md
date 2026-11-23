# Contributing to Throw

Thanks for helping out. Keep changes small and focused.

## Workflow

1. Fork the repository
2. Create a branch: `git checkout -b feature/short-name`
3. Make your changes, following the existing code style
4. Run the checks:

   ```bash
   flutter analyze
   flutter test
   ```

5. Push your branch and open a PR against `main`
6. The PR must pass CI before it can be merged

## Style notes

- Commit messages are plain lowercase sentences — no conventional-commit prefixes
- User-facing strings go in `lib/l10n/`, never hardcoded in widgets
- Layouts use the breakpoints in `lib/core/breakpoints.dart`, no hardcoded pixel sizes
- UI changes need a screenshot in the PR

## Code of conduct

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
