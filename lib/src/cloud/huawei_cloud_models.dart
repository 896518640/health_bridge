/// 华为健康云侧API数据模型
/// 
/// 提供与华为Health Kit云端API交互的数据结构

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

  // 血压相关
  static const String bloodPressureInstantaneous =
      'com.huawei.instantaneous.blood_pressure';
}

/// 字段名称常量
class FieldNames {
  // 步数字段
  static const String steps = 'steps';
  static const String stepsDelta = 'steps_delta';

  // 血糖字段
  static const String level = 'level';

  // 血糖统计字段
  static const String avg = 'avg'; // 平均值
  static const String max = 'max'; // 最大值
  static const String min = 'min'; // 最小值

  // 血压字段
  static const String systolicPressure = 'systolic_pressure';
  static const String diastolicPressure = 'diastolic_pressure';
}

// ============================================
// 请求参数模型
// ============================================

/// 【请求】多日统计查询请求参数
class DailyPolymerizeRequest {
  /// 原子采样明细数据类型的集合（最大容量：20）
  final List<String> dataTypes;

  /// 期望被聚合的数据开始日期（格式：yyyyMMdd）
  final String startDay;

  /// 期望被聚合的数据结束日期（格式：yyyyMMdd）
  final String endDay;

  /// 指定时区（格式：+0800） 
  final String timeZone;

  DailyPolymerizeRequest({
    required this.dataTypes,
    required this.startDay,
    required this.endDay,
    required this.timeZone,
  });

  Map<String, dynamic> toJson() {
    return {
      'dataTypes': dataTypes,
      'startDay': startDay,
      'endDay': endDay,
      'timeZone': timeZone,
    };
  }
}

/// 采样数据明细查询请求参数
class PolymerizeRequest {
  final List<PolymerizeWith> polymerizeWith;
  final int startTime;
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

class PolymerizeWith {
  final String dataTypeName;

  PolymerizeWith({required this.dataTypeName});

  Map<String, dynamic> toJson() {
    return {'dataTypeName': dataTypeName};
  }
}

// ============================================
// 响应数据模型
// ============================================

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

  /// 获取所有采样点（扁平化）
  List<SamplePoint> get allSamplePoints {
    final points = <SamplePoint>[];
    for (final group in groups) {
      for (final sampleSet in group.sampleSets) {
        points.addAll(sampleSet.samplePoints);
      }
    }
    return points;
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

/// 采样数据明细查询响应体
class PolymerizeResponse {
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

class PolymerizeGroup {
  final int startTime;
  final int endTime;
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

class SampleSet {
  final String dataCollectorId;
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

class SamplePoint {
  final int startTime;
  final int endTime;
  final String dataTypeName;
  final List<FieldValue> values;

  SamplePoint({
    required this.startTime,
    required this.endTime,
    required this.dataTypeName,
    required this.values,
  });

  factory SamplePoint.fromJson(Map<String, dynamic> json) {
    final valueList = json['value'] as List<dynamic>? ?? [];
    return SamplePoint(
      startTime: json['startTime'] as int,
      endTime: json['endTime'] as int,
      dataTypeName: json['dataTypeName'] as String,
      values: valueList
          .map((v) => FieldValue.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }

  DateTime get startDateTime =>
      DateTime.fromMillisecondsSinceEpoch(startTime ~/ 1000000);
  DateTime get endDateTime =>
      DateTime.fromMillisecondsSinceEpoch(endTime ~/ 1000000);
}

class FieldValue {
  final String fieldName;
  final int? integerValue;
  final double? floatValue;
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

  dynamic get value => integerValue ?? floatValue ?? stringValue;
}

// ============================================
// 扩展方法
// ============================================

extension PolymerizeResponseExt on PolymerizeResponse {
  List<SamplePoint> get allSamplePoints {
    final points = <SamplePoint>[];
    for (final group in groups) {
      for (final sampleSet in group.sampleSets) {
        points.addAll(sampleSet.samplePoints);
      }
    }
    return points;
  }
}

extension SamplePointStepsExt on SamplePoint {
  int? get stepsValue {
    for (final value in values) {
      if (value.fieldName == FieldNames.steps ||
          value.fieldName == FieldNames.stepsDelta) {
        return value.integerValue;
      }
    }
    return null;
  }
}

extension SamplePointBloodGlucoseExt on SamplePoint {
  double? get bloodGlucoseValue {
    for (final value in values) {
      if (value.fieldName == FieldNames.level) {
        return value.floatValue;
      }
    }
    return null;
  }
}

extension SamplePointBloodPressureExt on SamplePoint {
  double? get systolicPressure {
    for (final value in values) {
      if (value.fieldName == FieldNames.systolicPressure) {
        return value.floatValue;
      }
    }
    return null;
  }

  double? get diastolicPressure {
    for (final value in values) {
      if (value.fieldName == FieldNames.diastolicPressure) {
        return value.floatValue;
      }
    }
    return null;
  }
}

// ============================================
// 授权管理相关模型（新增）
// ============================================

/// 隐私授权状态
///
/// 用于表示用户在华为运动健康App中的授权状态
enum PrivacyAuthStatus {
  /// 已授权（可以访问健康数据）
  authorized(1, '已授权'),

  /// 未授权（需要引导用户去华为运动健康App开启授权）
  notAuthorized(2, '未授权'),

  /// 非华为运动健康App用户（用户没有安装或使用华为运动健康App）
  notHealthUser(3, '非华为运动健康用户');

  final int value;
  final String description;

  const PrivacyAuthStatus(this.value, this.description);

  /// 从 API 返回的 opinion 值创建状态
  factory PrivacyAuthStatus.fromOpinion(int opinion) {
    return PrivacyAuthStatus.values.firstWhere(
      (e) => e.value == opinion,
      orElse: () => PrivacyAuthStatus.notAuthorized,
    );
  }

  /// 是否已授权
  bool get isAuthorized => this == PrivacyAuthStatus.authorized;
}

/// 用户授权信息
///
/// 包含用户授权的所有权限详情
class UserConsentInfo {
  /// 权限URL到中文描述的映射
  ///
  /// 例如：
  /// - `https://www.huawei.com/healthkit/sleep.read` -> "查看华为 Health Service Kit 中的睡眠数据"
  final Map<String, String> scopeDescriptions;

  /// 授权时间
  final DateTime authTime;

  /// 应用名称
  final String appName;

  /// 应用图标路径（可选）
  final String? appIconPath;

  UserConsentInfo({
    required this.scopeDescriptions,
    required this.authTime,
    required this.appName,
    this.appIconPath,
  });

  /// 从 API 响应创建对象
  factory UserConsentInfo.fromJson(Map<String, dynamic> json) {
    // 解析 url2Desc
    final url2DescMap = json['url2Desc'] as Map<String, dynamic>? ?? {};
    final scopeDescriptions = url2DescMap.map(
      (key, value) => MapEntry(key, value.toString()),
    );

    // 解析授权时间（Unix时间戳，秒）
    final authTimeStr = json['authTime'] as String? ?? '0';
    final authTimeSeconds = int.tryParse(authTimeStr) ?? 0;
    final authTime = DateTime.fromMillisecondsSinceEpoch(authTimeSeconds * 1000);

    return UserConsentInfo(
      scopeDescriptions: scopeDescriptions,
      authTime: authTime,
      appName: json['appName'] as String? ?? '',
      appIconPath: json['appIconPath'] as String?,
    );
  }

  /// 获取已授权的 scope 列表
  List<String> get authorizedScopes => scopeDescriptions.keys.toList();

  /// 检查是否授权了特定权限
  bool hasScope(String scope) => scopeDescriptions.containsKey(scope);

  /// 获取权限数量
  int get scopeCount => scopeDescriptions.length;

  @override
  String toString() {
    return 'UserConsentInfo('
        'appName: $appName, '
        'authTime: $authTime, '
        'scopeCount: $scopeCount'
        ')';
  }
}
