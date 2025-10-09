import 'health_platform.dart';

/// 健康数据模型
class HealthData {
  const HealthData({
    required this.type,
    required this.value,
    required this.timestamp,
    required this.unit,
    required this.platform,
    this.source,
    this.metadata = const {},
  });

  /// 数据类型
  final HealthDataType type;

  /// 数据值
  final double value;

  /// 时间戳 (毫秒)
  final int timestamp;

  /// 单位
  final String unit;

  /// 来源平台
  final HealthPlatform platform;

  /// 数据来源应用/设备名称（如：Apple Watch, iPhone 等）
  final String? source;

  /// 额外元数据
  final Map<String, dynamic> metadata;

  /// 从JSON创建实例
  factory HealthData.fromJson(Map<String, dynamic> json) {
    return HealthData(
      type: HealthDataType.values.firstWhere(
        (type) => type.key == json['type'],
        orElse: () => HealthDataType.glucose,
      ),
      value: (json['value'] as num? ?? 0).toDouble(),
      timestamp: (json['timestamp'] as num? ?? 0).toInt(),
      unit: json['unit'] as String? ?? '',
      platform: HealthPlatform.values.firstWhere(
        (platform) => platform.key == json['platform'],
        orElse: () => HealthPlatform.samsungHealth,
      ),
      source: json['source'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type.key,
      'value': value,
      'timestamp': timestamp,
      'unit': unit,
      'platform': platform.key,
      'source': source,
      'metadata': metadata,
    };
  }

  /// 创建副本
  HealthData copyWith({
    HealthDataType? type,
    double? value,
    int? timestamp,
    String? unit,
    HealthPlatform? platform,
    String? source,
    Map<String, dynamic>? metadata,
  }) {
    return HealthData(
      type: type ?? this.type,
      value: value ?? this.value,
      timestamp: timestamp ?? this.timestamp,
      unit: unit ?? this.unit,
      platform: platform ?? this.platform,
      source: source ?? this.source,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'HealthData(type: ${type.key}, value: $value ${unit}, '
        'timestamp: $timestamp, platform: ${platform.key})';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HealthData &&
            runtimeType == other.runtimeType &&
            type == other.type &&
            value == other.value &&
            timestamp == other.timestamp &&
            unit == other.unit &&
            platform == other.platform;
  }

  @override
  int get hashCode {
    return type.hashCode ^
        value.hashCode ^
        timestamp.hashCode ^
        unit.hashCode ^
        platform.hashCode;
  }
}

/// 健康数据查询结果
class HealthDataResult {
  const HealthDataResult({
    required this.status,
    required this.platform,
    this.data = const [],
    this.message,
    this.totalCount = 0,
  });

  /// 查询状态
  final HealthDataStatus status;
  
  /// 数据来源平台
  final HealthPlatform platform;
  
  /// 健康数据列表
  final List<HealthData> data;
  
  /// 状态消息
  final String? message;
  
  /// 数据总数
  final int totalCount;

  /// 是否成功
  bool get isSuccess => status == HealthDataStatus.success;

  /// 从JSON创建实例
  factory HealthDataResult.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List<dynamic>? ?? [];
    final healthDataList = dataList
        .map((item) => HealthData.fromJson(item as Map<String, dynamic>))
        .toList();

    return HealthDataResult(
      status: _parseStatus(json['status']),
      platform: HealthPlatform.values.firstWhere(
        (platform) => platform.key == json['platform'],
        orElse: () => HealthPlatform.samsungHealth,
      ),
      data: healthDataList,
      message: json['message'] as String?,
      totalCount: (json['totalSteps'] as int?) ?? 
                   (json['count'] as int?) ?? 
                   healthDataList.length,
    );
  }

  static HealthDataStatus _parseStatus(dynamic status) {
    if (status == null) return HealthDataStatus.error;
    
    switch (status.toString()) {
      case 'success':
        return HealthDataStatus.success;
      case 'permission_denied':
        return HealthDataStatus.permissionDenied;
      case 'platform_not_supported':
        return HealthDataStatus.platformNotSupported;
      case 'not_initialized':
        return HealthDataStatus.notInitialized;
      case 'connection_failed':
        return HealthDataStatus.connectionFailed;
      default:
        return HealthDataStatus.error;
    }
  }

  @override
  String toString() {
    return 'HealthDataResult(status: $status, platform: ${platform.key}, '
        'dataCount: ${data.length}, message: $message)';
  }
}