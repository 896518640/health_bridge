import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dnurse_health_plugin/dnurse_health_plugin_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelDnurseHealthPlugin platform = MethodChannelDnurseHealthPlugin();
  const MethodChannel channel = MethodChannel('dnurse_health_plugin');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
