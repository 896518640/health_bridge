import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'health_bridge_method_channel.dart';
import 'models/health_data.dart';
import 'models/health_platform.dart';

/// HealthBridge平台接口的抽象基类
abstract class HealthBridgePlatform extends PlatformInterface {
  /// 构造函数
  HealthBridgePlatform() : super(token: _token);

  static final Object _token = Object();

  static HealthBridgePlatform _instance = MethodChannelHealthBridge();

  /// 当前平台实现的默认实例
  static HealthBridgePlatform get instance => _instance;

  /// 设置平台实现实例，主要用于测试
  static set instance(HealthBridgePlatform instance) {
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
  /// 
  /// [platform] 数据源健康平台
  /// [startDate] 开始日期，为null时读取今日数据
  /// [endDate] 结束日期，为null时读取startDate当日数据
  /// 
  /// 使用示例：
  /// - readStepCount(platform: platform) // 读取今日
  /// - readStepCount(platform: platform, startDate: date) // 读取指定日期
  /// - readStepCount(platform: platform, startDate: start, endDate: end) // 读取日期范围
  Future<HealthDataResult> readStepCount({
    required HealthPlatform platform,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    throw UnimplementedError('readStepCount() has not been implemented.');
  }

  /// 断开所有健康平台连接
  Future<void> disconnect() {
    throw UnimplementedError('disconnect() has not been implemented.');
  }
}