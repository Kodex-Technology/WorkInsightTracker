# Coding standards

## General

- Minimum high-quality code for correct behavior
- No overengineering, speculative features, or unused code
- No duplicate business logic
- Prefer readable straight-line code over pattern theater
- Comments only for non-obvious intent

## Dart / Flutter

- `flutter analyze` must be clean on touched code
- Prefer `const` constructors
- Dispose listeners/subscriptions
- Feature-oriented folders; avoid file sprawl for tiny features
- Riverpod for state; GoRouter for navigation
- Immutable view-state where it clarifies rebuilds

## Native C++

- RAII; explicit error paths; no memory leaks
- No uncontrolled threads or busy loops
- One engine implementation

## Changes

Substantial architecture changes → entry in [../planning/decisions.md](../planning/decisions.md).
