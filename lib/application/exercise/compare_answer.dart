class CompareAnswer {
  const CompareAnswer();
  bool call(String answer, String expected) =>
      _normalize(answer) == _normalize(expected);
  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s\.,!?;:]+'), ' ').trim();
}
