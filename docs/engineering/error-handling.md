# Error handling

- Domain operations return typed results/errors — not silent catches
- Native failures surface as engine error state + diagnostics detail
- Permission denials → PermissionRequired UX, not crash
- Persist enough context for recovery without losing user trust
- User-facing copy: clear, non-blaming, actionable
