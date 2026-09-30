/// Backend-agnostic chat kit: typed models, built-in SQLite cache, offline
/// outbox, controllers, and a customizable chat room and inbox UI.
///
/// The app implements `ChatSource` (Firebase, Supabase, REST, ...); the kit
/// owns everything else. Build order lives in `spec/tasks/`.
library;

export 'src/builders/chat_builders.dart';
export 'src/builders/inbox_builders.dart';
export 'src/builders/message_context.dart';
export 'src/cache/chat_cache.dart';
export 'src/cache/drift_chat_cache.dart';
export 'src/config/chat_config.dart';
export 'src/config/chat_formatters.dart';
export 'src/config/chat_strings.dart';
export 'src/config/chat_theme.dart';
export 'src/controllers/chat_kit.dart';
export 'src/controllers/chat_kit_scope.dart';
export 'src/controllers/chat_room_controller.dart';
export 'src/controllers/composer_controller.dart';
export 'src/controllers/inbox_controller.dart';
export 'src/models/attachment.dart';
export 'src/models/chat_event.dart';
export 'src/models/chat_json_keys.dart';
export 'src/models/chat_page.dart';
export 'src/models/chat_room.dart';
export 'src/models/chat_user.dart';
export 'src/models/message.dart';
export 'src/models/message_cursor.dart';
export 'src/models/message_status.dart';
export 'src/models/presence.dart';
export 'src/models/room_member.dart';
export 'src/models/typing.dart';
export 'src/source/chat_source.dart';
export 'src/source/chat_uploader.dart';
export 'src/source/chat_user_resolver.dart';
export 'src/sync/chat_repository.dart';
export 'src/sync/outbox.dart';
export 'src/sync/outbox_entry.dart';
export 'src/sync/retry_policy.dart';
export 'src/sync/room_sync_state.dart';
export 'src/sync/room_window.dart';
