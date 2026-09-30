# Decisions

## D1 — Backend-agnostic core; the app implements `ChatSource`

**Choice:** One package with no backend SDK. The app implements `ChatSource`, `ChatUploader`, `ChatUserResolver` and maps its own DTOs to kit models.

**Why:** valizex uses Firestore, lightnessword uses Supabase, future apps may use REST or WebSockets. Adapter packages would multiply release work; a small contract plus adapter guides in `doc/` gives full control to the app.

**Do not:** Import `cloud_firestore`, `supabase_flutter`, `dio`, or any backend SDK in `lib/`.

## D2 — Built-in Drift cache

**Choice:** The kit ships its own SQLite cache through `drift` + `drift_flutter`, one file per user, on a background isolate. `ChatCache` stays an interface so tests can use `NativeDatabase.memory()`.

**Why:** Chat must open instantly and work offline. valizex's sqflite schema lost placeholders (missing `isUploading` column) and shared one sync key across rooms; lightnessword rewrote the whole chat blob on each append. Drift gives typed tables, `watch` queries, migrations, all six platforms (web via wasm), and is the family's entity store.

**Do not:** Store messages as a blob per room, or use `shared_preferences` for messages.

## D3 — `super_sliver_list` for the message list

**Choice:** Reversed `CustomScrollView` + `SuperSliverList` with a `ListController`.

**Why:** It jumps and animates to any index even with variable heights and unbuilt items, works with other slivers and scrollbars, and lays out faster than `SliverList`. `scrollable_positioned_list` (valizex) cannot combine with slivers and has scrollbar issues.

**Do not:** Use a non-reversed list with `shrinkWrap` and jump-to-max loops (lightnessword).

## D4 — Read pointers, not per-message seen flags

**Choice:** `RoomMember.lastReadAt` / `lastDeliveredAt`. A message is seen by a member when `createdAt <= lastReadAt`.

**Why:** Scales to groups (one row per member, not one flag per message per member), makes "seen by" avatars cheap, and `markRead(roomId, upTo)` is one write.

## D5 — Keyset cursors and per-room sync state

**Choice:** `MessageCursor(createdAt, id)` for `before` / `after`; `room_sync_state` stores newest synced cursor, oldest loaded cursor, `hasMoreOlder` per room.

**Why:** Offset and growing-limit paging re-download data and skip or duplicate messages when new ones arrive. A global sync key (valizex) skipped messages in other rooms.

## D6 — Plain `ChangeNotifier` controllers, no Riverpod

**Choice:** `ChatKit`, controllers, and progress values are `ChangeNotifier` / `ValueListenable`.

**Why:** A pub.dev chat kit must work with any state management. Apps using Riverpod wrap `ChatKit` in a provider (family rule: realtime and cached entities live in providers in the app).

**Do not:** Add `flutter_riverpod` to `lib/`.

## D7 — Builders receive the default child; `CustomMessage` for app types

**Choice:** Every builder is `(context, MessageContext, Widget defaultChild) => Widget` (or a defaults list for actions). App-specific message kinds use `CustomMessage(customType, data)` rendered by `ChatBuilders.customBuilders[customType]`.

**Why:** valizex needs offer/transaction cards and custom app bar actions. Wrapping the default keeps upgrades cheap; a registry keyed by type avoids forking the list.

## D8 — Media bundled in the core package

**Choice:** `cached_network_image`, `image_picker`, `file_picker`, `record`, `audioplayers`, `video_player` are direct dependencies. Pickers are overridable through `onAttachmentPick`.

**Why:** Chosen by the owner: images, voice, video and files must work out of the box. `audioplayers` is used for playback because it supports all six platforms, including Windows and Linux.

**Trade-off:** Apps inherit native plugin setup (permissions). Documented in `package.md`.

## D9 — Only `lemsa_core_kit` among Lemsa kits; own `ChatTheme`

**Choice:** Depend on `lemsa_core_kit` (`AppFailure`, `Result`, `Change`). Styling comes from `ChatTheme` (a `ThemeExtension`) with fallbacks from `ColorScheme`.

**Why:** Usable by any pub.dev app, not only apps on `flutter_scale_theme_kit`. A theme-kit bridge can be added later without a breaking change.

## D10 — Latest dependency versions; Flutter 3.44 minimum

**Choice:** `environment: flutter: ">=3.44.0"`. Every third-party package is added at its latest stable version (`flutter pub add <name>`, never a guessed version), and `flutter pub outdated` must show no direct dependency behind before a release.

**Why:** Owner requirement. The kit must build on Flutter 3.44 and later; recent plugin majors carry the platform fixes (Android Gradle, iOS privacy manifests, web wasm) that older ones lack.

**Do not:** Pin an old major to dodge a migration, or add a package whose latest version needs a Flutter newer than 3.44.

## D11 — Media is stored locally and reused

**Choice:** A `ChatMediaStore` keeps image, video, audio and file payloads on disk (app support directory, one folder per user) with an index table in the Drift cache (`remote_url` → `local_path`, `size`, `last_access`). The user's own sent files are copied into the store at send time, so they never download again. Received media is downloaded on first view (images, audio) or on demand (video, files), then read from disk. The store has a size limit with least-recently-used eviction, and is wiped by `clearUserData()`. A "Save" action exports a stored file through `FilePicker.saveFile` by default; apps can override it with `onSaveMedia` (for example to save to the gallery).

**Why:** Owner requirement. Local files open instantly, work offline, cut bandwidth, keep the list smooth, and make download/save trivial. On web the store falls back to the browser HTTP cache (no file system).

**Do not:** Re-download media the device already has, or keep message bytes in the SQLite rows.

## D12 — English defaults; every visible text is replaceable

**Choice:** All user-facing text (labels, hints, menu actions, errors, relative dates, system messages, accessibility labels) comes from `ChatStrings`, with English defaults. No widget contains a literal string. Apps translate by building `ChatStrings` from their own localization (`slang`, `intl`/ARB, `easy_localization`): plain fields for fixed text, functions for plurals and arguments. Dates and numbers use `ChatFormatters` with the app's locale.

**Why:** Owner requirement. The kit ships one language and never fights the app's i18n system.

**Do not:** Bundle ARB files or depend on a localization package in `lib/`.
