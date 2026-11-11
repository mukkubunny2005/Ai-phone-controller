class AutomationCommandParser {
  const AutomationCommandParser._();

  /// Normalize user commands without leaving literal regex escape sequences.
  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ;]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Split workflows on "then", "and then", or semicolons.
  static List<String> split(String value) => value
      .split(RegExp(r'\s+(?:and then|then)\s+|\s*;\s*'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}
