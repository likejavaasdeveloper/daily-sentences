class Sentence {
  const Sentence({
    required this.text,
    required this.translation,
    required this.usages,
  });
  final String text;
  final String translation;
  final List<String> usages;
}

class SentencePackage {
  const SentencePackage({
    required this.language,
    required this.category,
    required this.sentences,
  });
  final String language;
  final String category;
  final List<Sentence> sentences;
}
