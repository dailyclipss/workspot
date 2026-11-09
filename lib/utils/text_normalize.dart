const Map<String, String> _azFold = {
  'ə': 'e',
  'Ə': 'e',
  'ı': 'i',
  'İ': 'i',
  'I': 'i',
  'ş': 's',
  'Ş': 's',
  'ç': 'c',
  'Ç': 'c',
  'ğ': 'g',
  'Ğ': 'g',
  'ö': 'o',
  'Ö': 'o',
  'ü': 'u',
  'Ü': 'u',
};

final RegExp _separators = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// Lower-cases, folds Azerbaijani letters to ASCII and collapses every
/// non letter/digit run (spaces, slashes, dashes, punctuation) to one space.
String normalizeAz(String? input) {
  if (input == null || input.isEmpty) return '';
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_azFold[char] ?? char.toLowerCase());
  }
  return buffer.toString().replaceAll(_separators, ' ').trim();
}

/// True when [needle] occurs in [haystack] as whole words (both normalized).
bool containsWords(String haystack, String needle) {
  if (needle.isEmpty) return false;
  return ' $haystack '.contains(' $needle ');
}
