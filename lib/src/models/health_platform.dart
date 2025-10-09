/// 健康数据类型枚举
enum HealthDataType {
  // === 基础运动指标 ===
  steps('steps', 'Steps', 'count'),
  distance('distance', 'Distance', 'meters'),
  activeCalories('active_calories', 'Active Calories', 'kcal'),

  // === 血糖相关 ===
  glucose('glucose', 'Blood Glucose', 'mmol/L'),

  // === 心血管 ===
  heartRate('heart_rate', 'Heart Rate', 'bpm'),
  bloodPressureSystolic('blood_pressure_systolic', 'Systolic Blood Pressure', 'mmHg'),
  bloodPressureDiastolic('blood_pressure_diastolic', 'Diastolic Blood Pressure', 'mmHg'),

  // === 身体指标 ===
  weight('weight', 'Weight', 'kg'),
  height('height', 'Height', 'cm'),
  bodyFat('body_fat', 'Body Fat Percentage', '%'),
  bmi('bmi', 'BMI', 'kg/m²'),

  // === 睡眠 ===
  sleepDuration('sleep_duration', 'Sleep Duration', 'minutes'),
  sleepDeep('sleep_deep', 'Deep Sleep', 'minutes'),
  sleepLight('sleep_light', 'Light Sleep', 'minutes'),
  sleepREM('sleep_rem', 'REM Sleep', 'minutes'),

  // === 营养 ===
  water('water', 'Water Intake', 'ml'),
  nutrition('nutrition', 'Nutrition', 'kcal'),

  // === 运动类型 ===
  workout('workout', 'Workout', 'minutes'),
  cycling('cycling', 'Cycling', 'minutes'),
  running('running', 'Running', 'minutes'),

  // === 其他健康指标 ===
  oxygenSaturation('oxygen_saturation', 'Blood Oxygen Saturation', '%'),
  bodyTemperature('body_temperature', 'Body Temperature', '°C'),
  respiratoryRate('respiratory_rate', 'Respiratory Rate', 'breaths/min');

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

  /// 获取该平台支持的能力列表
  List<PlatformCapability> get capabilities {
    switch (this) {
      case HealthPlatform.samsungHealth:
        return _samsungHealthCapabilities;
      case HealthPlatform.appleHealth:
        return _appleHealthCapabilities;
      case HealthPlatform.googleFit:
        return _googleFitCapabilities;
      case HealthPlatform.huaweiHealth:
        return _huaweiHealthCapabilities;
    }
  }

  /// 检查是否支持某个数据类型的操作
  bool supports(HealthDataType dataType, {required HealthDataOperation operation}) {
    final capability = capabilities.firstWhere(
      (cap) => cap.dataType == dataType,
      orElse: () => PlatformCapability(
        dataType: dataType,
        canRead: false,
        canWrite: false,
      ),
    );
    return capability.supports(operation);
  }

  /// 获取支持的所有数据类型
  List<HealthDataType> getSupportedDataTypes({HealthDataOperation? operation}) {
    if (operation == null) {
      return capabilities.map((cap) => cap.dataType).toList();
    }

    return capabilities
        .where((cap) => cap.supports(operation))
        .map((cap) => cap.dataType)
        .toList();
  }

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
  dataTypeNotSupported,
  notInitialized,
  connectionFailed
}

/// 数据操作类型
enum HealthDataOperation {
  read('read', 'Read'),
  write('write', 'Write');

  const HealthDataOperation(this.key, this.displayName);

  final String key;
  final String displayName;
}

/// 权限状态枚举
enum HealthPermissionStatus {
  granted('granted', 'Granted'),
  denied('denied', 'Denied'),
  notDetermined('not_determined', 'Not Determined'),
  restricted('restricted', 'Restricted');

  const HealthPermissionStatus(this.key, this.displayName);

  final String key;
  final String displayName;

  bool get isGranted => this == HealthPermissionStatus.granted;
  bool get isDenied => this == HealthPermissionStatus.denied;
  bool get canRequest => this == HealthPermissionStatus.notDetermined;
}

/// 权限组定义
enum HealthPermissionGroup {
  bloodGlucose('blood_glucose', 'Blood Glucose Management', [
    HealthDataType.glucose,
  ]),
  activity('activity', 'Activity & Exercise', [
    HealthDataType.steps,
    HealthDataType.distance,
    HealthDataType.activeCalories,
    HealthDataType.workout,
    HealthDataType.cycling,
    HealthDataType.running,
  ]),
  vitals('vitals', 'Vital Signs', [
    HealthDataType.heartRate,
    HealthDataType.bloodPressureSystolic,
    HealthDataType.bloodPressureDiastolic,
    HealthDataType.oxygenSaturation,
    HealthDataType.bodyTemperature,
    HealthDataType.respiratoryRate,
  ]),
  body('body', 'Body Measurements', [
    HealthDataType.weight,
    HealthDataType.height,
    HealthDataType.bodyFat,
    HealthDataType.bmi,
  ]),
  sleep('sleep', 'Sleep Analysis', [
    HealthDataType.sleepDuration,
    HealthDataType.sleepDeep,
    HealthDataType.sleepLight,
    HealthDataType.sleepREM,
  ]),
  nutrition('nutrition', 'Nutrition & Hydration', [
    HealthDataType.water,
    HealthDataType.nutrition,
  ]);

  const HealthPermissionGroup(this.key, this.displayName, this.dataTypes);

  final String key;
  final String displayName;
  final List<HealthDataType> dataTypes;
}

/// 平台能力定义
class PlatformCapability {
  const PlatformCapability({
    required this.dataType,
    required this.canRead,
    required this.canWrite,
    this.requiresSpecialPermission = false,
    this.notes,
  });

  final HealthDataType dataType;
  final bool canRead;
  final bool canWrite;
  final bool requiresSpecialPermission;
  final String? notes;

  bool supports(HealthDataOperation operation) {
    switch (operation) {
      case HealthDataOperation.read:
        return canRead;
      case HealthDataOperation.write:
        return canWrite;
    }
  }
}

// ========== 平台能力映射定义 ==========

/// Samsung Health 能力映射
const List<PlatformCapability> _samsungHealthCapabilities = [
  // 基础运动指标
  PlatformCapability(dataType: HealthDataType.steps, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.distance, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.activeCalories, canRead: true, canWrite: true),

  // 血糖 - Samsung Health 完整支持
  PlatformCapability(dataType: HealthDataType.glucose, canRead: true, canWrite: true),

  // 心血管
  PlatformCapability(dataType: HealthDataType.heartRate, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.bloodPressureSystolic, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.bloodPressureDiastolic, canRead: true, canWrite: true),

  // 身体指标
  PlatformCapability(dataType: HealthDataType.weight, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.height, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.bodyFat, canRead: true, canWrite: true),

  // 睡眠
  PlatformCapability(dataType: HealthDataType.sleepDuration, canRead: true, canWrite: true),

  // 营养
  PlatformCapability(dataType: HealthDataType.water, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.nutrition, canRead: true, canWrite: true),

  // 运动
  PlatformCapability(dataType: HealthDataType.workout, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.cycling, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.running, canRead: true, canWrite: true),

  // 血氧
  PlatformCapability(dataType: HealthDataType.oxygenSaturation, canRead: true, canWrite: true),
];

/// Apple Health 能力映射
const List<PlatformCapability> _appleHealthCapabilities = [
  // 基础运动指标
  PlatformCapability(dataType: HealthDataType.steps, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.distance, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.activeCalories, canRead: true, canWrite: true),

  // 血糖 - Apple Health 完整支持
  PlatformCapability(dataType: HealthDataType.glucose, canRead: true, canWrite: true),

  // 心血管
  PlatformCapability(dataType: HealthDataType.heartRate, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.bloodPressureSystolic, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.bloodPressureDiastolic, canRead: true, canWrite: true),

  // 身体指标
  PlatformCapability(dataType: HealthDataType.weight, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.height, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.bodyFat, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.bmi, canRead: true, canWrite: true),

  // 睡眠 - Apple Health 详细支持
  PlatformCapability(dataType: HealthDataType.sleepDuration, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.sleepDeep, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.sleepLight, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.sleepREM, canRead: true, canWrite: true),

  // 营养
  PlatformCapability(dataType: HealthDataType.water, canRead: true, canWrite: true),

  // 运动
  PlatformCapability(dataType: HealthDataType.workout, canRead: true, canWrite: true),

  // 其他
  PlatformCapability(dataType: HealthDataType.oxygenSaturation, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.bodyTemperature, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.respiratoryRate, canRead: true, canWrite: true),
];

/// Google Fit 能力映射
const List<PlatformCapability> _googleFitCapabilities = [
  // 基础运动指标
  PlatformCapability(dataType: HealthDataType.steps, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.distance, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.activeCalories, canRead: true, canWrite: true),

  // 血糖 - Google Fit 有限支持
  PlatformCapability(
    dataType: HealthDataType.glucose,
    canRead: true,
    canWrite: true,
    notes: 'Limited support, may require third-party apps',
  ),

  // 心血管
  PlatformCapability(dataType: HealthDataType.heartRate, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.bloodPressureSystolic, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.bloodPressureDiastolic, canRead: true, canWrite: true),

  // 身体指标
  PlatformCapability(dataType: HealthDataType.weight, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.height, canRead: true, canWrite: true),

  // 睡眠 - Google Fit 基础支持
  PlatformCapability(dataType: HealthDataType.sleepDuration, canRead: true, canWrite: true),

  // 营养
  PlatformCapability(
    dataType: HealthDataType.water,
    canRead: true,
    canWrite: true,
    notes: 'Requires Fit app version 2.0+',
  ),
  PlatformCapability(dataType: HealthDataType.nutrition, canRead: true, canWrite: true),

  // 运动
  PlatformCapability(dataType: HealthDataType.workout, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.cycling, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.running, canRead: true, canWrite: true),

  // 血氧 - 只读
  PlatformCapability(dataType: HealthDataType.oxygenSaturation, canRead: true, canWrite: false),
];

/// Huawei Health 能力映射
const List<PlatformCapability> _huaweiHealthCapabilities = [
  // 基础运动指标
  PlatformCapability(dataType: HealthDataType.steps, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.distance, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.activeCalories, canRead: true, canWrite: true),

  // 血糖 - Huawei Health 支持
  PlatformCapability(dataType: HealthDataType.glucose, canRead: true, canWrite: true),

  // 心血管
  PlatformCapability(dataType: HealthDataType.heartRate, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.bloodPressureSystolic, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.bloodPressureDiastolic, canRead: true, canWrite: true),

  // 身体指标
  PlatformCapability(dataType: HealthDataType.weight, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.height, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.bodyFat, canRead: true, canWrite: false),

  // 睡眠 - Huawei Health 详细支持（只读）
  PlatformCapability(dataType: HealthDataType.sleepDuration, canRead: true, canWrite: false),
  PlatformCapability(dataType: HealthDataType.sleepDeep, canRead: true, canWrite: false),
  PlatformCapability(dataType: HealthDataType.sleepLight, canRead: true, canWrite: false),

  // 运动
  PlatformCapability(dataType: HealthDataType.workout, canRead: true, canWrite: true),

  // 血氧 - Huawei 特色功能
  PlatformCapability(dataType: HealthDataType.oxygenSaturation, canRead: true, canWrite: true),
];