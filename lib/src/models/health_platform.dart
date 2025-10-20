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

  /// 血压（复合数据类型）
  ///
  /// 返回的数据中 value 为 null，实际数据在 metadata 中：
  /// - metadata['systolic']: 收缩压
  /// - metadata['diastolic']: 舒张压
  ///
  /// 平台特有字段也会保留在 metadata 中（如华为的脉搏、测量姿势等）
  bloodPressure('blood_pressure', 'Blood Pressure', 'mmHg'),

  /// 收缩压（废弃）
  ///
  /// 此类型已废弃，请使用 [bloodPressure] 代替。
  /// 从 metadata 中读取：metadata['systolic']
  @Deprecated('Use bloodPressure instead. Access systolic value via metadata["systolic"]')
  bloodPressureSystolic('blood_pressure_systolic', 'Systolic Blood Pressure', 'mmHg'),

  /// 舒张压（废弃）
  ///
  /// 此类型已废弃，请使用 [bloodPressure] 代替。
  /// 从 metadata 中读取：metadata['diastolic']
  @Deprecated('Use bloodPressure instead. Access diastolic value via metadata["diastolic"]')
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
  respiratoryRate('respiratory_rate', 'Respiratory Rate', 'breaths/min'),
  skinTemperature('skin_temperature', 'Skin Temperature', '°C'),
  floorsClimbed('floors_climbed', 'Floors Climbed', 'floors'),

  // === 目标类型 (Goal Types) ===
  stepsGoal('steps_goal', 'Steps Goal', 'count'),
  activeCaloriesGoal('active_calories_goal', 'Active Calories Goal', 'kcal'),
  activeTimeGoal('active_time_goal', 'Active Time Goal', 'minutes'),
  sleepGoal('sleep_goal', 'Sleep Goal', 'minutes'),
  waterGoal('water_goal', 'Water Intake Goal', 'ml'),
  nutritionGoal('nutrition_goal', 'Nutrition Goal', 'kcal'),

  // === 特殊类型 ===
  energyScore('energy_score', 'Energy Score', 'score'),
  workoutLocation('workout_location', 'Workout Location', 'coordinates'),
  userProfile('user_profile', 'User Profile', 'profile');

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
  huaweiHealth('huawei_health', 'Huawei Health', 'Android'),
  huaweiCloud('huawei_cloud', 'Huawei Health Cloud', 'All');

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
      case HealthPlatform.huaweiCloud:
        return _huaweiCloudCapabilities;
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
/// 基于 Samsung Health Data SDK 23 个 DataType 完整映射
/// 参考: https://developer.samsung.com/health/data/api-reference
const List<PlatformCapability> _samsungHealthCapabilities = [
  // 1. STEPS - 步数
  PlatformCapability(dataType: HealthDataType.steps, canRead: true, canWrite: false),

  // 2. HEART_RATE - 心率
  PlatformCapability(dataType: HealthDataType.heartRate, canRead: true, canWrite: false),

  // 3. SLEEP - 睡眠（支持所有睡眠阶段）
  PlatformCapability(dataType: HealthDataType.sleepDuration, canRead: true, canWrite: false),
  PlatformCapability(dataType: HealthDataType.sleepDeep, canRead: true, canWrite: false),
  PlatformCapability(dataType: HealthDataType.sleepLight, canRead: true, canWrite: false),
  PlatformCapability(dataType: HealthDataType.sleepREM, canRead: true, canWrite: false),

  // 4. EXERCISE - 运动
  PlatformCapability(dataType: HealthDataType.workout, canRead: true, canWrite: false),

  // 5. EXERCISE_LOCATION - 运动位置
  PlatformCapability(dataType: HealthDataType.workoutLocation, canRead: true, canWrite: false),

  // 6. BLOOD_PRESSURE - 血压
  PlatformCapability(dataType: HealthDataType.bloodPressureSystolic, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.bloodPressureDiastolic, canRead: true, canWrite: true),

  // 7. BLOOD_GLUCOSE - 血糖
  PlatformCapability(dataType: HealthDataType.glucose, canRead: true, canWrite: true),

  // 8. BLOOD_OXYGEN - 血氧
  PlatformCapability(dataType: HealthDataType.oxygenSaturation, canRead: true, canWrite: false),

  // 9. BODY_TEMPERATURE - 体温
  PlatformCapability(dataType: HealthDataType.bodyTemperature, canRead: true, canWrite: true),

  // 10. SKIN_TEMPERATURE - 皮肤温度
  PlatformCapability(dataType: HealthDataType.skinTemperature, canRead: true, canWrite: false),

  // 11. BODY_COMPOSITION - 身体成分（体重、身高、体脂、BMI）
  PlatformCapability(dataType: HealthDataType.weight, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.height, canRead: true, canWrite: true),
  PlatformCapability(dataType: HealthDataType.bodyFat, canRead: true, canWrite: false),
  PlatformCapability(dataType: HealthDataType.bmi, canRead: true, canWrite: false),

  // 12. WATER_INTAKE - 饮水量
  PlatformCapability(dataType: HealthDataType.water, canRead: true, canWrite: true),

  // 13. NUTRITION - 营养
  PlatformCapability(dataType: HealthDataType.nutrition, canRead: true, canWrite: true),

  // 14. FLOORS_CLIMBED - 爬楼层数
  PlatformCapability(dataType: HealthDataType.floorsClimbed, canRead: true, canWrite: false),

  // 15. ACTIVITY_SUMMARY - 活动总结（包含活动卡路里、距离等）
  PlatformCapability(dataType: HealthDataType.activeCalories, canRead: true, canWrite: false),
  PlatformCapability(dataType: HealthDataType.distance, canRead: true, canWrite: false),

  // 16. ENERGY_SCORE - 能量分数
  PlatformCapability(dataType: HealthDataType.energyScore, canRead: true, canWrite: false),

  // 17. USER_PROFILE - 用户资料
  PlatformCapability(dataType: HealthDataType.userProfile, canRead: true, canWrite: true),

  // === Goal Types (目标类型) - 只读 ===
  // 18. STEPS_GOAL - 步数目标
  PlatformCapability(dataType: HealthDataType.stepsGoal, canRead: true, canWrite: false),

  // 19. ACTIVE_CALORIES_BURNED_GOAL - 活动卡路里目标
  PlatformCapability(dataType: HealthDataType.activeCaloriesGoal, canRead: true, canWrite: false),

  // 20. ACTIVE_TIME_GOAL - 活动时间目标
  PlatformCapability(dataType: HealthDataType.activeTimeGoal, canRead: true, canWrite: false),

  // 21. SLEEP_GOAL - 睡眠目标
  PlatformCapability(dataType: HealthDataType.sleepGoal, canRead: true, canWrite: false),

  // 22. WATER_INTAKE_GOAL - 饮水目标
  PlatformCapability(dataType: HealthDataType.waterGoal, canRead: true, canWrite: false),

  // 23. NUTRITION_GOAL - 营养目标
  PlatformCapability(dataType: HealthDataType.nutritionGoal, canRead: true, canWrite: false),
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
/// 注意：华为Health Kit仅支持3种数据类型的读取权限
/// - 步数 (steps)
/// - 血糖 (glucose)
/// - 血压 (bloodPressure) - 复合数据，包含收缩压和舒张压
const List<PlatformCapability> _huaweiHealthCapabilities = [
  // 步数
  PlatformCapability(
    dataType: HealthDataType.steps,
    canRead: true,
    canWrite: false,
    notes: 'Read-only support',
  ),

  // 血糖
  PlatformCapability(
    dataType: HealthDataType.glucose,
    canRead: true,
    canWrite: false,
    requiresSpecialPermission: true,
    notes: 'Read-only support, requires manual review approval',
  ),

  // 血压（统一类型）
  PlatformCapability(
    dataType: HealthDataType.bloodPressure,
    canRead: true,
    canWrite: false,
    requiresSpecialPermission: true,
    notes: 'Read-only support, requires manual review approval. Returns both systolic and diastolic values in metadata.',
  ),
];

/// Huawei Health Cloud 能力映射
/// 通过华为云侧 API 访问健康数据（需要 OAuth 授权）
const List<PlatformCapability> _huaweiCloudCapabilities = [
  // 步数
  PlatformCapability(
    dataType: HealthDataType.steps,
    canRead: true,
    canWrite: false,
    notes: 'Cloud API access, requires OAuth authorization',
  ),

  // 血糖
  PlatformCapability(
    dataType: HealthDataType.glucose,
    canRead: true,
    canWrite: false,
    requiresSpecialPermission: true,
    notes: 'Cloud API access, requires OAuth authorization',
  ),

  // 血压
  PlatformCapability(
    dataType: HealthDataType.bloodPressure,
    canRead: true,
    canWrite: false,
    requiresSpecialPermission: true,
    notes: 'Cloud API access, requires OAuth authorization',
  ),
];