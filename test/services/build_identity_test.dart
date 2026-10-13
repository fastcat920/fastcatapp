import 'package:fl_clash/common/build_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provenance only contains allowlisted non-sensitive values', () {
    expect(BuildIdentity.normalizedCommit('ABCDEF0123456789'), 'abcdef012345');
    expect(BuildIdentity.normalizedCommit('bad\nAuthorization: private'),
        'unknown');
    expect(BuildIdentity.normalizedCommit('main'), 'unknown');
    expect(BuildIdentity.normalizedChannel('normal'), 'normal');
    expect(BuildIdentity.normalizedChannel('signed'), 'signed');
    expect(BuildIdentity.normalizedChannel('secret-token'), 'local');
  });
}
