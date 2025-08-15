import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dnurse_health_plugin_method_channel.dart';
import 'models/health_data.dart';
import 'models/health_platform.dart';

/// DnurseHealthPlugin平台接口的抽象基类
abstract class DnurseHealthPluginPlatform extends PlatformInterface {
  /// 构造函数
  DnurseHealthPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static DnurseHealthPluginPlatform _instance = MethodChannelDnurseHealthPlugin();

  /// 当前平台实现的默认实例
  static DnurseHealthPluginPlatform get instance => _instance;

  /// 设置平台实现实例，主要用于测试
  static set instance(DnurseHealthPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// 获取平台版本
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  /// 获取当前设备支持的健康平台列表
  Future<List<HealthPlatform>> getAvailableHealthPlatforms() {
    throw UnimplementedError('getAvailableHealthPlatforms() has not been implemented.');
  }

  /// 初始化指定的健康平台
  Future<HealthDataResult> initializeHealthPlatform(HealthPlatform platform) {
    throw UnimplementedError('initializeHealthPlatform() has not been implemented.');
  }

  /// 读取步数数据
  Future<HealthDataResult> readStepCount({
    required HealthPlatform platform,
  }) {
    throw UnimplementedError('readStepCount() has not been implemented.');
  }

  /// 读取指定日期的步数数据
  Future<HealthDataResult> readStepCountForDate({
    required DateTime date,
    required HealthPlatform platform,
  }) {
    throw UnimplementedError('readStepCountForDate() has not been implemented.');
  }

  /// 读取指定日期范围的步数数据
  Future<HealthDataResult> readStepCountForDateRange({
    required DateTime startDate,
    required DateTime endDate,
    required HealthPlatform platform,
  }) {
    throw UnimplementedError('readStepCountForDateRange() has not been implemented.');
  }

  /// 断开所有健康平台连接
  Future<void> disconnect() {
    throw UnimplementedError('disconnect() has not been implemented.');
  }
}