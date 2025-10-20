import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'huawei_health_api_models.dart';

/// 华为健康云侧API服务
///
/// 提供统计查询和明细查询两个核心接口
class HuaweiHealthApiService {
  final Dio _dio;
  final String _accessToken;
  final String _clientId;

  /// 基础URL
  static const String baseUrl = 'https://health-api.cloud.huawei.com/healthkit';

  HuaweiHealthApiService({
    required String accessToken,
    required String clientId,
    Dio? dio,
  })  : _accessToken = accessToken,
        _clientId = clientId,
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ));

  /// 【统计接口】多日统计查询 (dailyPolymerize)
  ///
  /// 用途：按天聚合数据，查询每日统计值
  ///
  /// 示例：
  /// ```dart
  /// final request = DailyPolymerizeRequest(
  ///   dataTypes: [HuaweiDataTypes.stepsTotal],
  ///   startDay: '20231010',
  ///   endDay: '20231017',
  ///   timeZone: '+0800',
  /// );
  /// final response = await service.dailyPolymerize(request);
  /// ```
  Future<DailyPolymerizeResponse> dailyPolymerize(
    DailyPolymerizeRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '$baseUrl/v2/sampleSet:dailyPolymerize',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'x-client-id': _clientId,
            'Content-Type': 'application/json',
          },
        ),
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        // 如果是血糖查询，打印原始响应
        // if (request.dataTypes.any((type) => type.contains('blood_glucose'))) {
        //   debugPrint('[API响应] ${jsonEncode(response.data)}');
        // }
        debugPrint('[API响应] ${jsonEncode(response.data)}');
        return DailyPolymerizeResponse.fromJson(
            response.data as Map<String, dynamic>);
      } else {
        throw HuaweiApiException(
          statusCode: response.statusCode ?? 0,
          message: 'HTTP ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// 【明细接口】采样数据明细查询 (polymerize)
  ///
  /// 用途：查询原始采样点的详细数据（不按天聚合）
  ///
  /// 示例：
  /// ```dart
  /// final request = PolymerizeRequest(
  ///   polymerizeWith: [PolymerizeWith(dataTypeName: HuaweiDataTypes.stepsDelta)],
  ///   startTime: 1697500800000,
  ///   endTime: 1697587199999,
  /// );
  /// final response = await service.polymerize(request);
  /// ```
  Future<PolymerizeResponse> polymerize(PolymerizeRequest request) async {
    try {
      final response = await _dio.post(
        '$baseUrl/v2/sampleSet:polymerize',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'x-client-id': _clientId,
            'Content-Type': 'application/json',
          },
        ),
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        debugPrint('[API响应] ${jsonEncode(response.data)}');
        return PolymerizeResponse.fromJson(
            response.data as Map<String, dynamic>);
      } else {
        throw HuaweiApiException(
          statusCode: response.statusCode ?? 0,
          message: 'HTTP ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// 处理Dio异常
  HuaweiApiException _handleDioException(DioException e) {
    if (e.response != null) {
      final data = e.response!.data;
      String message = e.message ?? 'Unknown error';

      if (data is Map<String, dynamic>) {
        final error = data['error'];
        if (error is Map<String, dynamic>) {
          message = error['message'] ?? data['message'] ?? message;
        } else {
          message = data['message'] ?? message;
        }
      }

      return HuaweiApiException(
        statusCode: e.response!.statusCode ?? 0,
        message: message,
        data: data,
      );
    } else {
      return HuaweiApiException(
        statusCode: 0,
        message: e.message ?? 'Network error',
      );
    }
  }
}

/// 华为API异常
class HuaweiApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic data;

  HuaweiApiException({
    required this.statusCode,
    required this.message,
    this.data,
  });

  @override
  String toString() {
    return 'HuaweiApiException(statusCode: $statusCode, message: $message)';
  }
}

// ============================================
// 便捷扩展方法
// ============================================

/// DailyPolymerizeResponse 扩展方法
extension DailyPolymerizeResponseExt on DailyPolymerizeResponse {
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

  /// 按日期获取采样点
  Map<DateTime, List<SamplePoint>> get samplePointsByDate {
    final map = <DateTime, List<SamplePoint>>{};
    for (final group in groups) {
      final date = DateTime(
        group.date.year,
        group.date.month,
        group.date.day,
      );
      final points = <SamplePoint>[];
      for (final sampleSet in group.sampleSets) {
        points.addAll(sampleSet.samplePoints);
      }
      map[date] = points;
    }
    return map;
  }
}

/// PolymerizeResponse 扩展方法
extension PolymerizeResponseExt on PolymerizeResponse {
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

/// SamplePoint 扩展方法 - 步数相关
extension SamplePointStepsExt on SamplePoint {
  /// 获取步数值（兼容 steps 和 steps_delta）
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

/// SamplePoint 扩展方法 - 血糖相关
extension SamplePointBloodGlucoseExt on SamplePoint {
  /// 获取血糖值（明细数据）
  double? get bloodGlucoseValue {
    for (final value in values) {
      if (value.fieldName == FieldNames.level) {
        return value.floatValue;
      }
    }
    return null;
  }

  /// 获取样本来源
  int? get sampleSource {
    for (final value in values) {
      if (value.fieldName == FieldNames.sampleSource) {
        return value.integerValue;
      }
    }
    return null;
  }

  /// 获取测量时机
  int? get measureTime {
    for (final value in values) {
      if (value.fieldName == FieldNames.measureTime) {
        return value.integerValue;
      }
    }
    return null;
  }

  /// 获取平均值（统计数据）
  double? get avgValue {
    for (final value in values) {
      if (value.fieldName == FieldNames.avg) {
        return value.floatValue;
      }
    }
    return null;
  }

  /// 获取最大值（统计数据）
  double? get maxValue {
    for (final value in values) {
      if (value.fieldName == FieldNames.max) {
        return value.floatValue;
      }
    }
    return null;
  }

  /// 获取最小值（统计数据）
  double? get minValue {
    for (final value in values) {
      if (value.fieldName == FieldNames.min) {
        return value.floatValue;
      }
    }
    return null;
  }
}

/// SamplePoint 扩展方法 - 血压相关
extension SamplePointBloodPressureExt on SamplePoint {
  /// 获取收缩压值
  double? get systolicPressure {
    for (final value in values) {
      if (value.fieldName == FieldNames.systolicPressure) {
        return value.floatValue;
      }
    }
    return null;
  }

  /// 获取舒张压值
  double? get diastolicPressure {
    for (final value in values) {
      if (value.fieldName == FieldNames.diastolicPressure) {
        return value.floatValue;
      }
    }
    return null;
  }

  /// 获取脉搏值
  int? get sphygmus {
    for (final value in values) {
      if (value.fieldName == FieldNames.sphygmus) {
        return value.integerValue;
      }
    }
    return null;
  }

  /// 获取测量姿势
  int? get measurePosture {
    for (final value in values) {
      if (value.fieldName == FieldNames.measurePosture) {
        return value.integerValue;
      }
    }
    return null;
  }

  /// 获取身体姿势
  int? get bodyPosture {
    for (final value in values) {
      if (value.fieldName == FieldNames.bodyPosture) {
        return value.integerValue;
      }
    }
    return null;
  }

  /// 获取测量手臂
  int? get armSide {
    for (final value in values) {
      if (value.fieldName == FieldNames.armSide) {
        return value.integerValue;
      }
    }
    return null;
  }
}
