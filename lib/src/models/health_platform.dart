/// 健康数据类型枚举
enum HealthDataType {
  glucose('glucose', 'Blood Glucose', 'mmol/L'),
  steps('steps', 'Steps', 'steps'),
  heartRate('heart_rate', 'Heart Rate', 'bpm'),
  bloodPressure('blood_pressure', 'Blood Pressure', 'mmHg'),
  weight('weight', 'Weight', 'kg'),
  sleep('sleep', 'Sleep', 'minutes');

  const HealthDataType(this.key, this.displayName, this.unit);

  final String key;
  final String displayName;
  final String unit;
}

/// 健康数据平台枚举
enum HealthPlatform {
  samsungHealth('samsung_health', 'Samsung Health', 'Android'),
  appleHealth('apple_health', 'Apple Health', 'iOS'),
  googleFit('google_fit', 'Google Fit', 'Android'), 
  huaweiHealth('huawei_health', 'Huawei Health', 'Android');

  const HealthPlatform(this.key, this.displayName, this.platform);

  final String key;
  final String displayName;
  final String platform;

  /// 获取当前平台可用的健康平台
  static List<HealthPlatform> getAvailablePlatformsForCurrentOS() {
    // 这里应该根据实际平台返回，暂时返回所有
    return HealthPlatform.values;
  }
}

/// 健康数据状态枚举
enum HealthDataStatus {
  success,
  error,
  permissionDenied,
  platformNotSupported,
  notInitialized,
  connectionFailed
}