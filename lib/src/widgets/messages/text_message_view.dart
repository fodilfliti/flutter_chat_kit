import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_kit/src/config/chat_strings.dart';

/// Called with an `https:`, `mailto:` or `tel:` URI when a link is tapped.
typedef LinkTapCallback = void Function(Uri uri);

/// Message text with tappable links, e-mails and phone numbers, a "read
/// more" toggle for long texts, and large rendering for short emoji-only
/// messages.
class TextMessageView extends StatefulWidget {
  const TextMessageView({
    required this.text,
    required this.style,
    this.linkStyle,
    this.onLinkTap,
    this.collapseAfter = 700,
    this.strings = const ChatStrings(),
    super.key,
  });

  final String text;
  final TextStyle style;

  /// Defaults to [style] underlined.
  final TextStyle? linkStyle;

  /// Links are highlighted but not tappable without it.
  final LinkTapCallback? onLinkTap;

  /// Texts longer than this many characters start collapsed.
  final int collapseAfter;
  final ChatStrings strings;

  /// Whether [text] is one to three emoji and nothing else.
  static bool isEmojiOnly(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _other.hasMatch(trimmed)) return false;
    if (!_pictographic.hasMatch(trimmed)) return false;
    return trimmed.characters.where((c) => c.trim().isNotEmpty).length <= 3;
  }

  static final _pictographic = RegExp(
    // valid_regexps ignores `unicode: true`, which property escapes need.
    // ignore: valid_regexps
    r'\p{Extended_Pictographic}|\p{Regional_Indicator}',
    unicode: true,
  );
  static final _other = RegExp(
    // valid_regexps ignores `unicode: true`, which property escapes need.
    // ignore: valid_regexps
    r'[^\p{Extended_Pictographic}\p{Emoji_Component}\p{Emoji_Modifier}'
    r'\u200d\ufe0f\u20e3\s]',
    unicode: true,
  );

  /// URLs (`http(s)://` or `www.`), e-mail addresses and phone numbers.
  static final linkPattern = RegExp(
    r'''((?:https?://|www\.)[^\s<>]*[^\s<>.,;:!?'")\]}])'''
    r'|([\w.+-]+@[\w-]+(?:\.[\w-]+)+)'
    r'|(\+?\d[\d ().-]{6,}\d)',
    caseSensitive: false,
  );

  /// The URI for a [linkPattern] match, or null when it isn't a link (for
  /// example a number with too few digits).
  static Uri? uriOf(RegExpMatch match) {
    final url = match.group(1);
    if (url != null) {
      return Uri.tryParse(
        url.toLowerCase().startsWith('www.') ? 'https://$url' : url,
      );
    }
    final email = match.group(2);
    if (email != null) return Uri(scheme: 'mailto', path: email);
    final phone = match.group(3);
    if (phone == null) return null;
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final count = digits.replaceAll('+', '').length;
    if (count < 8 || count > 15) return null;
    return Uri(scheme: 'tel', path: digits);
  }

  @override
  State<TextMessageView> createState() => _TextMessageViewState();
}

class _TextMessageViewState extends State<TextMessageView> {
  final _recognizers = <GestureRecognizer>[];
  bool _expanded = false;

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  TapGestureRecognizer _tap(VoidCallback onTap) {
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final text = widget.text;
    if (TextMessageView.isEmojiOnly(text)) {
      final size = (widget.style.fontSize ?? 16) * 2.4;
      return Text(text.trim(), style: widget.style.copyWith(fontSize: size));
    }

    final collapsible = text.characters.length > widget.collapseAfter;
    final shown = collapsible && !_expanded
        ? '${text.characters.take(widget.collapseAfter)}…'
        : text;
    final linkStyle =
        widget.linkStyle ??
        widget.style.copyWith(decoration: TextDecoration.underline);
    final spans = <InlineSpan>[..._linkify(shown, linkStyle)];
    if (collapsible) {
      spans
        ..add(const TextSpan(text: ' '))
        ..add(
          TextSpan(
            text: _expanded ? widget.strings.readLess : widget.strings.readMore,
            style: widget.style.copyWith(fontWeight: FontWeight.w600),
            recognizer: _tap(() => setState(() => _expanded = !_expanded)),
          ),
        );
    }
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }

  Iterable<InlineSpan> _linkify(String text, TextStyle linkStyle) sync* {
    var start = 0;
    for (final match in TextMessageView.linkPattern.allMatches(text)) {
      final uri = TextMessageView.uriOf(match);
      if (uri == null) continue;
      if (match.start > start) {
        yield TextSpan(text: text.substring(start, match.start));
      }
      final onLinkTap = widget.onLinkTap;
      yield TextSpan(
        text: match[0],
        style: linkStyle,
        recognizer: onLinkTap == null ? null : _tap(() => onLinkTap(uri)),
      );
      start = match.end;
    }
    if (start < text.length) yield TextSpan(text: text.substring(start));
  }
}
