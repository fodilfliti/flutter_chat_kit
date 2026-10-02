import 'package:flutter/widgets.dart';

/// Returns the chat's scale for the current screen. Called by `ChatStyle`
/// in `build`, after it subscribed to the screen size, so it runs again on
/// every resize and rotation.
typedef ChatScaler = ChatScale Function(BuildContext context);

/// How much bigger or smaller the chat is drawn than its design values.
///
/// [size] multiplies every size, padding, radius, border and shadow;
/// [text] every font size. With a screen-size package, pass its factors
/// for one design pixel, so the chat matches the rest of the app exactly:
///
/// ```dart
/// ChatStyle(
///   // flutter_scale_kit or flutter_screenutil:
///   scale: (context) => ChatScale(1.w, text: 1.sp),
///   // scale: ChatScale.byScreen(), // no package
///   child: ...,
/// )
/// ```
///
/// These packages compute `14.w` as `14 * 1.w`, so every chat size equals
/// the package's value for the same design number.
///
/// The system text size (accessibility) is applied by Flutter on top of
/// [text]; do not include it.
@immutable
class ChatScale {
  /// Multiplies sizes by [size] and fonts by [text], which defaults to
  /// [size].
  const ChatScale(this.size, {double? text}) : text = text ?? size;

  /// No scaling.
  static const none = ChatScale(1);

  /// Multiplies sizes, paddings, radii, borders and shadows.
  final double size;

  /// Multiplies font sizes.
  final double text;

  /// True when nothing changes.
  bool get isNone => size == 1 && text == 1;

  /// This scale times [other], for a zoom setting on top of a screen scale.
  ChatScale operator *(ChatScale other) =>
      ChatScale(size * other.size, text: text * other.text);

  /// The same scale everywhere, for example a zoom setting.
  static ChatScaler fixed(double size, {double? text}) {
    final scale = ChatScale(size, text: text);
    return (_) => scale;
  }

  /// Compares the short side of the screen with [designWidth] (the width
  /// of your phone design), clamped to [min]..[max]. Using the short side
  /// keeps the same size when the phone rotates.
  static ChatScaler byScreen({
    double designWidth = 375,
    double min = 0.85,
    double max = 1.3,
  }) {
    assert(designWidth > 0 && min > 0 && min <= max, 'Invalid byScreen range');
    return (context) {
      final screen = MediaQuery.maybeSizeOf(context);
      if (screen == null || screen.isEmpty) return none;
      return ChatScale((screen.shortestSide / designWidth).clamp(min, max));
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ChatScale && other.size == size && other.text == text;

  @override
  int get hashCode => Object.hash(size, text);

  @override
  String toString() => 'ChatScale($size, text: $text)';
}
