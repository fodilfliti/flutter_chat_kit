# T11 — Composer

## Goal

The input area: text, attachments, voice notes, reply and edit — all replaceable, with pickers the app can override.

## Read first

- valizex `message_input_area_widget.dart`, `attachment_options_modal_widget.dart`, `VoiceRecordingDialog.dart` (hold, swipe to cancel, review)

## Depends on

T08, T10.

## Deliverables

```text
lib/src/widgets/composer/chat_composer.dart        ChatComposer
lib/src/widgets/composer/reply_edit_banner.dart
lib/src/widgets/composer/attachment_sheet.dart     camera / gallery / video / file (+ app extra options)
lib/src/widgets/composer/staged_attachments.dart   thumbnails with remove before sending
lib/src/widgets/composer/voice_record_button.dart  hold to record, slide left to cancel, slide up to lock, review (play / delete / send)
lib/src/media/default_pickers.dart                 image_picker / file_picker wrappers -> List<Attachment> (reads width/height/size/mime)
test/widgets/composer_test.dart
```

## Public API

```dart
typedef AttachmentPicker = Future<List<Attachment>> Function(BuildContext context, AttachmentSource source);
enum AttachmentSource { camera, gallery, video, file }

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    required this.controller,          // ComposerController
    this.onAttachmentPick,             // override default pickers
    this.extraAttachmentOptions = const [], // e.g. "Offer" -> app opens its own form, then sendCustom
    this.leading, this.trailing,       // extra buttons
    this.enableVoice = true, this.enableAttachments = true,
    this.inputDecoration, this.maxLines = 6,
  });
}
```

## Behaviour

- Send button replaces mic when there is text or staged attachments; `AnimatedSwitcher`.
- Enter sends on desktop/web (Shift+Enter newline); multiline on mobile.
- Reply banner shows author + snippet; edit banner pre-fills text; Esc / close cancels.
- Attachments hidden when `ChatKit.uploader == null`.
- Respects safe area and keyboard insets; no jump when the keyboard opens.

## Done when

- [x] Widget tests: typing toggles mic/send; submit clears text and draft; reply banner cancel; edit submits `edit`; custom picker override is called; extra option callback fires; voice: short press shows hint, long press records, slide cancel discards
- [x] Works on desktop with keyboard shortcuts

## As built

- **`ChatComposer`.** On top of the API above it takes `sendOnEnter` (defaults to true on desktop and web), `recorder` (an injectable `VoiceRecorderController`), `onError` (defaults to a snack bar: `attachmentTooLarge` for a `ValidationFailure`, otherwise `failedToSend`), `focusNode`, `strings` and `formatters`.
  - Keys go through a `Focus.onKeyEvent` above the field. Enter sends unless Shift is held or an IME composition is active; Esc cancels a reply or edit.
  - The action button sits in an `AnimatedSwitcher` whose outgoing child ignores pointers. The row children are keyed so the mic keeps its gesture while the bar changes.
  - Voice and attachments are hidden without `ChatKit.uploader` and while editing. Picked files over `ChatConfig.maxAttachmentBytes` are dropped with a snack bar.
- **Voice.**
  - `VoiceRecordButton`: tap shows the hint; hold records; sliding 100 px towards the start edge cancels (RTL aware); sliding 70 px up locks. Releasing sends, or shows the hint if the recording was too short. A denied permission shows `microphoneDenied`.
  - While recording, the text field becomes a bar: time and "slide to cancel" while holding; delete / time / stop when locked; delete and an `AudioMessageView` preview in review. The action becomes send.
  - `RecordBackend` creates the platform recorder on first use.
- **Pickers.** `DefaultAttachmentPicker` covers camera (`pickImage`), gallery (`pickMultipleMedia`), video (`pickVideo`) and file (`FilePicker.pickFiles` in file_picker 13). `attachmentFromXFile` reads the size, the MIME type (from the file, else from the extension via `mimeTypeForPath`), image dimensions from the header (`ImageDescriptor`, without a full decode), and video size and duration (`video_player`, native only, 5 s timeout).
- **Other widgets.** `AttachmentOption` (built-in options carry a `source`; app options use `onSelected`), `AttachmentSheet.show`, `StagedAttachments` (image thumbnails decoded at `cacheWidth`, a remove button each) and `ReplyEditBanner` (reuses `ReplyPreview`).
- **Strings (D12).** New `ChatStrings` entries: `attach`, `removeAttachment`, `recordVoice`, `holdToRecord`, `microphoneDenied`, `slideUpToLock`, `stopRecording`.

## Do not

- Request permissions outside `record` / `image_picker` flows
- Upload from the composer (the outbox does)
