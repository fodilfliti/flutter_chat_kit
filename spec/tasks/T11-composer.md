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

- [ ] Widget tests: typing toggles mic/send; submit clears text and draft; reply banner cancel; edit submits `edit`; custom picker override is called; extra option callback fires; voice: short press shows hint, long press records, slide cancel discards
- [ ] Works on desktop with keyboard shortcuts

## Do not

- Request permissions outside `record` / `image_picker` flows
- Upload from the composer (the outbox does)
