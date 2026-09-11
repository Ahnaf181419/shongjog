import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/text_loader.dart';
import 'package:shongjog/features/rag/persona_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PersonaLoader', () {
    setUp(() {
      TextLoader.debugClearCache();
    });

    test('loadPersona bn has Bangla escalation + bilingual rules', () async {
      final bundle = await loadPersona('bn');
      expect(bundle.persona, contains('Shongjog'));
      expect(bundle.rules, contains('Safety rules'));
      expect(bundle.escalation, contains('৯৯৯'));
      expect(bundle.emergencyKeywords, contains('জরুরি'));
    });

    test('loadPersona en has English escalation', () async {
      final bundle = await loadPersona('en');
      expect(bundle.persona, contains('Shongjog'));
      expect(bundle.escalation.toLowerCase(), contains('999'));
      expect(bundle.emergencyKeywords, contains('emergency'));
    });

    test('systemInstruction concatenates persona + rules', () async {
      final bundle = await loadPersona('en');
      expect(bundle.systemInstruction, contains(bundle.persona));
      expect(bundle.systemInstruction, contains(bundle.rules));
    });
  });
}
