# Agent instructions — Flutter Chat Pro

This is a **Flutter package** (`flutter_chat_pro`), not an application.

## Load context

1. Read `spec/README.md`, then `package.md` / `invariants.md` / `decisions.md`.
2. Pick the next open task in `spec/tasks/README.md` and read that task file. Build **one task per session**.
3. Use **code** under `lib/` as implementation truth.
4. Do **not** ingest `README.md` as working memory.

## Working rules

- Public export only via `lib/flutter_chat_pro.dart`. Add exports alphabetically as each task lands.
- Backend-agnostic: the app implements `ChatSource`, `ChatUploader`, `ChatUserResolver`. Never import a backend SDK.
- Forbidden in `lib/`: `firebase_*`, `cloud_firestore`, `supabase*`, `dio`, `http` clients for a specific backend, `flutter_riverpod`, `hooks_riverpod`, `riverpod_annotation`, `slang`, `easy_localization`, `.tr(`.
- The UI reads from the cache only; the repository fills the cache. Widgets never call `ChatSource` directly.
- Controllers are plain `ChangeNotifier` / `ValueListenable`. Anything with `dispose()` is owned and disposed by its creator.
- Models are immutable with value equality, `copyWith`, `toJson` / `fromJson`.
- Kits never localize: every user-facing string comes from `ChatStrings`; every date/size format from `ChatFormatters`.
- Every builder receives the default child so apps can wrap instead of rebuild.
- Sources throw `AppFailure` (from `lemsa_core_kit`). Do not leak vendor exceptions. Empty catches are analyzer errors.
- Drift generated files (`*.g.dart`) are committed. Regenerate with `fvm dart run build_runner build -d`.

## Flutter SDK

Pinned in `.fvmrc` to **3.47.2**. Use `fvm flutter` / `fvm dart`. Never upgrade the shared Flutter SDK.

## Out of scope unless asked

Publishing, backend adapter packages, Riverpod bindings, other kits, migrating valizex / lightnessword.
