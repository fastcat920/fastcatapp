import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/models/models.dart';

class TestDelaySource extends DelayDataSource {
  @override
  DelayMap build() => {};
  @override
  onUpdate(value) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'refresh keeps previous RTT; completion and explicit clearing replace it',
      () {
    final container = ProviderContainer(overrides: [
      delayDataSourceProvider.overrideWith(TestDelaySource.new),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(delayDataSourceProvider, (_, __) {});
    addTearDown(subscription.close);
    final source = container.read(delayDataSourceProvider.notifier);
    source.value = {};
    source.setDelay(Delay(url: 'test', name: 'node', value: 38));
    final previous = container.read(delayDataSourceProvider);
    source.setDelay(Delay(url: 'test', name: 'node', value: 0));
    expect(container.read(delayDataSourceProvider)['test']?['node']?.value, 38);
    source.setDelay(Delay(url: 'test', name: 'node', value: 45));
    expect(container.read(delayDataSourceProvider)['test']?['node']?.value, 45);
    expect(previous['test']?['node']?.value, 38);
    source.setDelay(Delay(url: 'test', name: 'node', value: -1));
    expect(
      container
          .read(delayDataSourceProvider)['test']?['node']
          ?.effectiveFailureKind,
      DelayFailureKind.failed,
    );
    source.setDelay(Delay.fromJson({
      'url': 'test',
      'name': 'node',
      'value': -1,
      'failure-kind': 'timeout',
    }));
    expect(
      container
          .read(delayDataSourceProvider)['test']?['node']
          ?.effectiveFailureKind,
      DelayFailureKind.timeout,
    );
    source.setDelay(Delay.fromJson({
      'url': 'test',
      'name': 'node',
      'value': -1,
      'failure-kind': 'unrecognized',
    }));
    expect(
      container
          .read(delayDataSourceProvider)['test']?['node']
          ?.effectiveFailureKind,
      DelayFailureKind.failed,
    );
    source.value = {};
    expect(container.read(delayDataSourceProvider), isEmpty);
  });
}
