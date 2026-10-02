import 'package:flutter_chat_pro/flutter_chat_pro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const strings = ChatStrings();

  test('typing handles 1, 2 and 3+ names', () {
    expect(strings.typing(['Ana']), 'Ana is typing');
    expect(strings.typing(['Ana', 'Bo']), 'Ana and Bo are typing');
    expect(strings.typing(['Ana', 'Bo', 'Cy']), '3 people are typing');
  });

  test('system uses args text, else the code', () {
    expect(strings.system('joined', {'text': 'Ana joined'}), 'Ana joined');
    expect(strings.system('joined', const {}), 'joined');
  });

  test('overrides keep other defaults', () {
    final fr = ChatStrings(
      reply: 'Répondre',
      typing: (names) => '${names.join(', ')} écrit',
    );
    expect(fr.reply, 'Répondre');
    expect(fr.copy, 'Copy');
    expect(fr.typing(['Ana']), 'Ana écrit');
  });
}
