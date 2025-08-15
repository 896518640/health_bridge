import 'health_bridge_platform_interface.dart';
import 'models/health_data.dart';
import 'models/health_platform.dart';

/// HealthBridge的主类，提供多平台健康数据集成功能
class HealthBridge {
  /// 获取平台版本信息
  static Future<String?> getPlatformVersion() {
    return HealthBridgePlatform.instance.getPlatformVersion();
  }

  /// 获取当前设备支持的健康平台列表
  /// 
  /// 返回当前设备上可用的健康平台，如Samsung Health、Apple Health等
  static Future<List<HealthPlatform>> getAvailableHealthPlatforms() {
    return HealthBridgePlatform.instance.getAvailableHealthPlatforms();
  }

  /// 初始化指定的健康平台
  /// 
  /// [platform] 要初始化的健康平台
  /// 返回初始化结果，包含连接状态和权限信息
  static Future<HealthDataResult> initializeHealthPlatform(
    HealthPlatform platform,
  ) {
    return HealthBridgePlatform.instance.initializeHealthPlatform(platform);
  }



  /// 从指定健康平台读取步数数据
  /// 
  /// [platform] 数据源健康平台
  /// 返回当天的步数统计数据
  static Future<HealthDataResult> readStepCount({
    required HealthPlatform platform,
  }) {
    return HealthBridgePlatform.instance.readStepCount(
      platform: platform,
    );
  }

  /// 从指定健康平台读取指定日期的步数数据
  /// 
  /// [date] 目标日期
  /// [platform] 数据源健康平台
  /// 返回该日期的步数统计数据
  static Future<HealthDataResult> readStepCountForDate({
    required DateTime date,
    required HealthPlatform platform,
  }) {
    return HealthBridgePlatform.instance.readStepCountForDate(
      date: date,
      platform: platform,
    );
  }

  /// 从指定健康平台读取指定日期范围的步数数据
  /// 
  /// [startDate] 开始日期
  /// [endDate] 结束日期
  /// [platform] 数据源健康平台
  /// 返回该日期范围的步数统计数据
  static Future<HealthDataResult> readStepCountForDateRange({
    required DateTime startDate,
    required DateTime endDate,
    required HealthPlatform platform,
  }) {
    return HealthBridgePlatform.instance.readStepCountForDateRange(
      startDate: startDate,
      endDate: endDate,
      platform: platform,
    );
  }

  /// 断开所有健康平台连接
  /// 
  /// 用于清理资源，通常在应用退出时调用
  static Future<void> disconnect() {
    return HealthBridgePlatform.instance.disconnect();
  }

  // 便利方法

  /// 检查Samsung Health是否可用
  static Future<bool> isSamsungHealthAvailable() async {
    final platforms = await getAvailableHealthPlatforms();
    return platforms.contains(HealthPlatform.samsungHealth);
  }

  /// 检查Apple Health是否可用  
  static Future<bool> isAppleHealthAvailable() async {
    final platforms = await getAvailableHealthPlatforms();
    return platforms.contains(HealthPlatform.appleHealth);
  }

  /// 自动选择最佳可用健康平台
  static Future<HealthPlatform?> getPreferredHealthPlatform() async {
    final platforms = await getAvailableHealthPlatforms();
    if (platforms.isEmpty) return null;

    // 优先级: Samsung Health > Apple Health > Google Fit > Huawei Health
    const preferenceOrder = [
      HealthPlatform.samsungHealth,
      HealthPlatform.appleHealth,
      HealthPlatform.googleFit,
      HealthPlatform.huaweiHealth,
    ];

    for (final preferred in preferenceOrder) {
      if (platforms.contains(preferred)) {
        return preferred;
      }
    }

    return platforms.first;
  }

  /// 初始化最佳可用健康平台
  static Future<HealthDataResult?> initializePreferredPlatform() async {
    final platform = await getPreferredHealthPlatform();
    if (platform == null) return null;

    return await initializeHealthPlatform(platform);
  }
}