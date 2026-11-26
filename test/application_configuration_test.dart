import 'package:daily_sentences/composition/app_composition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defines the application display name', () {
    const configuration = ApplicationConfiguration.dailySentences();

    expect(configuration.applicationName, 'Daily Sentences');
  });
}
