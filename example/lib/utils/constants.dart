import 'package:health_bridge/health_bridge.dart';

/// 所有支持的数据类型
final List<HealthDataType> allSupportedTypes = [
  HealthDataType.steps,
  HealthDataType.distance,
  HealthDataType.activeCalories,
  HealthDataType.glucose,
  HealthDataType.heartRate,
  HealthDataType.bloodPressure, // 使用新的统一血压类型
  HealthDataType.weight,
  HealthDataType.height,
  HealthDataType.bodyFat,
  HealthDataType.bmi,
  HealthDataType.oxygenSaturation,
  HealthDataType.bodyTemperature,
  HealthDataType.respiratoryRate,
  HealthDataType.water,
  HealthDataType.sleepDuration,
  HealthDataType.sleepDeep,
  HealthDataType.sleepLight,
  HealthDataType.sleepREM,
  HealthDataType.workout,
];

/// 可写入的数据类型
final List<HealthDataType> writableTypes = [
  HealthDataType.steps,
  HealthDataType.glucose,
  HealthDataType.weight,
  HealthDataType.height,
  HealthDataType.bodyFat,
  HealthDataType.oxygenSaturation,
  HealthDataType.bodyTemperature,
];
