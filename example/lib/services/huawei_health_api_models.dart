/// 华为健康云侧API数据模型
///
/// 包含请求参数和响应体的类型定义

// ============================================
// 统计接口 (dailyPolymerize) 相关模型
// ============================================

/// 【请求】多日统计查询请求参数
class DailyPolymerizeRequest {
  /// 原子采样明细数据类型的集合（最大容量：20）
  final List<String> dataTypes;

  /// 期望被聚合的数据开始日期（格式：yyyyMMdd，不早于20140101）
  final String startDay;

  /// 期望被聚合的数据结束日期（格式：yyyyMMdd）
  /// - endDay不小于startDay
  /// - endDay与startDay时间间隔不能超过31天
  final String endDay;

  /// 指定时区（格式：+0800）
  final String timeZone;

  DailyPolymerizeRequest({
    required this.dataTypes,
    required this.startDay,
    required this.endDay,
    required this.timeZone,
  }) {
    assert(dataTypes.isNotEmpty && dataTypes.length <= 20, 'dataTypes最大容量为20');
    assert(_isValidDateFormat(startDay), 'startDay格式错误，应为yyyyMMdd');
    assert(_isValidDateFormat(endDay), 'endDay格式错误，应为yyyyMMdd');
    assert(timeZone.isNotEmpty, 'timeZone不能为空');
  }

  bool _isValidDateFormat(String date) {
    final regex = RegExp(r'^\d{8}$');
    return regex.hasMatch(date);
  }

  Map<String, dynamic> toJson() {
    return {
      'dataTypes': dataTypes,
      'startDay': startDay,
      'endDay': endDay,
      'timeZone': timeZone,
    };
  }
}

/// 【响应】多日统计查询响应体
class DailyPolymerizeResponse {
  /// 分组数据列表
  final List<DailyGroup> groups;

  DailyPolymerizeResponse({required this.groups});

  factory DailyPolymerizeResponse.fromJson(Map<String, dynamic> json) {
    final groupList = json['group'] as List<dynamic>? ?? [];
    return DailyPolymerizeResponse(
      groups: groupList
          .map((g) => DailyGroup.fromJson(g as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 【响应】每日分组数据
class DailyGroup {
  /// 分组开始时间（毫秒时间戳）
  final int startTime;

  /// 分组结束时间（毫秒时间戳）
  final int endTime;

  /// 采样数据集列表
  final List<SampleSet> sampleSets;

  DailyGroup({
    required this.startTime,
    required this.endTime,
    required this.sampleSets,
  });

  factory DailyGroup.fromJson(Map<String, dynamic> json) {
    final sampleSetList = json['sampleSet'] as List<dynamic>? ?? [];
    return DailyGroup(
      startTime: json['startTime'] as int,
      endTime: json['endTime'] as int,
      sampleSets: sampleSetList
          .map((s) => SampleSet.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 获取这一天的日期
  DateTime get date => DateTime.fromMillisecondsSinceEpoch(startTime);
}

/// 【响应】采样数据集
class SampleSet {
  /// 数据采集器ID
  final String dataCollectorId;

  /// 采样点列表
  final List<SamplePoint> samplePoints;

  SampleSet({
    required this.dataCollectorId,
    required this.samplePoints,
  });

  factory SampleSet.fromJson(Map<String, dynamic> json) {
    final pointList = json['samplePoints'] as List<dynamic>? ?? [];
    return SampleSet(
      dataCollectorId: json['dataCollectorId'] as String,
      samplePoints: pointList
          .map((p) => SamplePoint.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 【响应】采样点数据
class SamplePoint {
  /// 采样点开始时间（纳秒时间戳）
  final int startTime;

  /// 采样点结束时间（纳秒时间戳）
  final int endTime;

  /// 数据类型名称
  final String dataTypeName;

  /// 原始数据采集器ID
  final String? originalDataCollectorId;

  /// 值列表
  final List<FieldValue> values;

  SamplePoint({
    required this.startTime,
    required this.endTime,
    required this.dataTypeName,
    this.originalDataCollectorId,
    required this.values,
  });

  factory SamplePoint.fromJson(Map<String, dynamic> json) {
    final valueList = json['value'] as List<dynamic>? ?? [];
    return SamplePoint(
      startTime: json['startTime'] as int,
      endTime: json['endTime'] as int,
      dataTypeName: json['dataTypeName'] as String,
      originalDataCollectorId: json['originalDataCollectorId'] as String?,
      values: valueList
          .map((v) => FieldValue.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 获取采样点的毫秒时间戳
  int get startTimeMillis => startTime ~/ 1000000;
  int get endTimeMillis => endTime ~/ 1000000;

  /// 获取采样点的DateTime
  DateTime get startDateTime =>
      DateTime.fromMillisecondsSinceEpoch(startTimeMillis);
  DateTime get endDateTime =>
      DateTime.fromMillisecondsSinceEpoch(endTimeMillis);
}

/// 【响应】字段值
class FieldValue {
  /// 字段名称
  final String fieldName;

  /// 整数值（可选）
  final int? integerValue;

  /// 浮点值（可选）
  final double? floatValue;

  /// 字符串值（可选）
  final String? stringValue;

  FieldValue({
    required this.fieldName,
    this.integerValue,
    this.floatValue,
    this.stringValue,
  });

  factory FieldValue.fromJson(Map<String, dynamic> json) {
    return FieldValue(
      fieldName: json['fieldName'] as String,
      integerValue: json['integerValue'] as int?,
      floatValue: json['floatValue'] as double?,
      stringValue: json['stringValue'] as String?,
    );
  }

  /// 获取任意类型的值
  dynamic get value => integerValue ?? floatValue ?? stringValue;
}

// ============================================
// 明细接口 (polymerize) 相关模型
// ============================================

/// 【请求】采样数据明细查询请求参数
class PolymerizeRequest {
  /// 聚合数据类型配置列表
  final List<PolymerizeWith> polymerizeWith;

  /// 开始时间（毫秒时间戳）
  final int startTime;

  /// 结束时间（毫秒时间戳）
  final int endTime;

  PolymerizeRequest({
    required this.polymerizeWith,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'polymerizeWith': polymerizeWith.map((p) => p.toJson()).toList(),
      'startTime': startTime,
      'endTime': endTime,
    };
  }
}

/// 【请求】聚合数据类型配置
class PolymerizeWith {
  /// 数据类型名称
  final String dataTypeName;

  PolymerizeWith({required this.dataTypeName});

  Map<String, dynamic> toJson() {
    return {
      'dataTypeName': dataTypeName,
    };
  }
}

/// 【响应】采样数据明细查询响应体
class PolymerizeResponse {
  /// 分组数据列表
  final List<PolymerizeGroup> groups;

  PolymerizeResponse({required this.groups});

  factory PolymerizeResponse.fromJson(Map<String, dynamic> json) {
    final groupList = json['group'] as List<dynamic>? ?? [];
    return PolymerizeResponse(
      groups: groupList
          .map((g) => PolymerizeGroup.fromJson(g as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 【响应】明细查询分组数据
class PolymerizeGroup {
  /// 分组开始时间（毫秒时间戳）
  final int startTime;

  /// 分组结束时间（毫秒时间戳）
  final int endTime;

  /// 采样数据集列表
  final List<SampleSet> sampleSets;

  PolymerizeGroup({
    required this.startTime,
    required this.endTime,
    required this.sampleSets,
  });

  factory PolymerizeGroup.fromJson(Map<String, dynamic> json) {
    final sampleSetList = json['sampleSet'] as List<dynamic>? ?? [];
    return PolymerizeGroup(
      startTime: json['startTime'] as int,
      endTime: json['endTime'] as int,
      sampleSets: sampleSetList
          .map((s) => SampleSet.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ============================================
// 常用数据类型常量
// ============================================

/// 华为健康数据类型常量
class HuaweiDataTypes {
  // 步数相关
  static const String stepsTotal = 'com.huawei.continuous.steps.total';
  static const String stepsDelta = 'com.huawei.continuous.steps.delta';

  // 血糖相关
  static const String bloodGlucoseInstantaneous =
      'com.huawei.instantaneous.blood_glucose';
  static const String bloodGlucoseCgm = 'com.huawei.cgm_blood_glucose';
  static const String bloodGlucoseCgmStats =
      'com.huawei.cgm_blood_glucose.statistics';

  // 血压相关
  static const String bloodPressure = 'com.huawei.blood.pressure';

  // 心率相关
  static const String heartRate = 'com.huawei.continuous.heart_rate';
}

/// 字段名称常量
class FieldNames {
  // 步数字段
  static const String steps = 'steps';
  static const String stepsDelta = 'steps_delta';

  // 血糖字段
  static const String level = 'level'; // 血糖值（修复：实际字段名是level）
  static const String measureTime = 'measure_time'; // 测量时机
  static const String sampleSource = 'sample_source';

  // 血糖统计字段
  static const String avg = 'avg'; // 平均值
  static const String max = 'max'; // 最大值
  static const String min = 'min'; // 最小值

  // 血压字段
  static const String systolicPressure = 'systolic_pressure';
  static const String diastolicPressure = 'diastolic_pressure';

  // 心率字段
  static const String heartRate = 'heart_rate';
}
