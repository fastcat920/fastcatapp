import 'dart:convert';

/// Split only the assignment, never Base64 padding or '=' inside a value.
Map<String, String> dartDefinesToMap(List<String> arguments) {
  const prefix = '--dart-define=';
  return Map.fromEntries(arguments.map((argument) {
    if (!argument.startsWith(prefix)) {
      throw ArgumentError('Expected a dart-define argument');
    }
    final assignment = argument.substring(prefix.length);
    final separator = assignment.indexOf('=');
    if (separator <= 0) throw ArgumentError('Invalid dart-define assignment');
    return MapEntry(
      assignment.substring(0, separator),
      assignment.substring(separator + 1),
    );
  }));
}

/// Fail packaging if Flutter did not receive the original configuration.
/// Values are deliberately omitted from errors and CI output.
void verifyCompiledDartDefines(
  String generatedCmake,
  Map<String, String> expected,
) {
  final match =
      RegExp(r'"DART_DEFINES=([^"\r\n]*)"').firstMatch(generatedCmake);
  if (match == null) throw StateError('Flutter DART_DEFINES are missing');
  final actual = dartDefinesToMap(match.group(1)!.split(',').map((encoded) {
    return '--dart-define=${utf8.decode(base64.decode(encoded))}';
  }).toList());
  for (final entry in expected.entries) {
    if (actual[entry.key] != entry.value) {
      throw StateError('Flutter build parameter mismatch: ${entry.key}');
    }
  }
}
