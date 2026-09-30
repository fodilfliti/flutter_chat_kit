import 'package:flutter_chat_kit/flutter_chat_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('barrel exposes models, contracts and config', () {
    expect(const ChatConfig().pageSize, 30);
    expect(MessageStatus.parse('seen'), MessageStatus.seen);
  });
}
