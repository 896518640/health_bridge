import 'package:flutter_test/flutter_test.dart';
import 'package:health_bridge/health_bridge.dart';
import 'package:health_bridge/src/health_bridge_platform_interface.dart';
import 'package:health_bridge/src/health_bridge_method_channel.dart';
import 'package:health_bridge/src/models/health_data.dart';
import 'package:health_bridge/src/models/health_platform.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHealthBridgePlatform
    with MockPlatformInterfaceMixin
    implements HealthBridgePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<List<HealthPlatform>> getAvailableHealthPlatforms() =>
      Future.value([HealthPlatform.samsungHealth]);

  @override
  Future<HealthDataResult> initializeHealthPlatform(HealthPlatform platform) =>
      Future.value(const HealthDataResult(
        status: HealthDataStatus.success,
        platform: HealthPlatform.samsungHealth,
      ));

  @override
  Future<HealthDataResult> readStepCount({required HealthPlatform platform, DateTime? startDate, DateTime? endDate}) =>
      Future.value(const HealthDataResult(
        status: HealthDataStatus.success,
        platform: HealthPlatform.samsungHealth,
        data: [],
      ));

  @override
  Future<void> disconnect() => Future.value();

  // 使用 noSuchMethod 处理其他未实现的方法
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // 返回默认的成功结果
    if (invocation.memberName.toString().contains('Future')) {
      return Future.value(const HealthDataResult(
        status: HealthDataStatus.success,
        platform: HealthPlatform.samsungHealth,
      ));
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  final HealthBridgePlatform initialPlatform = HealthBridgePlatform.instance;

  test('$MethodChannelHealthBridge is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelHealthBridge>());
  });

  test('getPlatformVersion', () async {
    MockHealthBridgePlatform fakePlatform = MockHealthBridgePlatform();
    HealthBridgePlatform.instance = fakePlatform;

    expect(await HealthBridge.getPlatformVersion(), '42');
  });
}
