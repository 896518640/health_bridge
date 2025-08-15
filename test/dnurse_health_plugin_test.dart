import 'package:flutter_test/flutter_test.dart';
import 'package:dnurse_health_plugin/dnurse_health_plugin.dart';
import 'package:dnurse_health_plugin/dnurse_health_plugin_platform_interface.dart';
import 'package:dnurse_health_plugin/dnurse_health_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDnurseHealthPluginPlatform
    with MockPlatformInterfaceMixin
    implements DnurseHealthPluginPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final DnurseHealthPluginPlatform initialPlatform = DnurseHealthPluginPlatform.instance;

  test('$MethodChannelDnurseHealthPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelDnurseHealthPlugin>());
  });

  test('getPlatformVersion', () async {
    DnurseHealthPlugin dnurseHealthPlugin = DnurseHealthPlugin();
    MockDnurseHealthPluginPlatform fakePlatform = MockDnurseHealthPluginPlatform();
    DnurseHealthPluginPlatform.instance = fakePlatform;

    expect(await dnurseHealthPlugin.getPlatformVersion(), '42');
  });
}
