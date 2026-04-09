# RefSeek — Lessons Learned

## Patterns & Rules

1. **SwiftData requires Xcode** — Cannot build with SwiftData macros from command line without Xcode. Use `Codable` + JSON file persistence instead.
2. **Sci-Hub mirrors change frequently** — Put working mirrors first, dead ones last. Default order should be tested periodically.
3. **Sci-Hub HTML uses escaped slashes** — The `location.href` in onclick attributes uses `\/` instead of `/`. Regex patterns must handle this.
4. **UTType(filenameExtension:) can return nil** — Always provide a fallback (e.g., `.plainText`). Never force-unwrap.
5. **@Published properties need manual Codable** — `ObservableObject` with `@Published` requires custom `encode(to:)` and `init(from:)`.
6. **Notes need onChange save** — TextEditor bindings don't auto-persist. Add `.onChange` to trigger `store.save()`.
7. **Unpaywall requires real email** — `test@example.com` returns 422. User must configure their own email in Settings.

## Mistakes to Avoid

1. Don't import `SwiftData` in files that don't use it — causes unnecessary build dependency.
2. Don't use `.accentColor` as a `ShapeStyle` member — use `Color.accentColor` instead.
3. Don't force-unwrap URL constructors — especially with user-provided mirror URLs.
