/// Non-sensitive, compile-time release provenance. Local builds are explicit;
/// never infer a production identity from the marketing version alone.
class BuildIdentity {
  static const _commit = String.fromEnvironment('FASTCAT_BUILD_COMMIT');
  static const _channel =
      String.fromEnvironment('FASTCAT_BUILD_CHANNEL', defaultValue: 'local');

  static String get commit => normalizedCommit(_commit);
  static String get channel => normalizedChannel(_channel);

  static String normalizedCommit(String value) => RegExp(r'^[a-fA-F0-9]{7,40}$')
          .hasMatch(value)
      ? value.substring(0, value.length > 12 ? 12 : value.length).toLowerCase()
      : 'unknown';

  static String normalizedChannel(String value) =>
      const {'local', 'normal', 'signed'}.contains(value) ? value : 'local';

  static String get label => '$channel / $commit';
}
