import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/health_data.dart';
import '../models/health_platform.dart';
import 'huawei_cloud_models.dart';

/// 华为健康云侧API客户端
/// 
/// 提供访问华为Health Kit云端API的能力
class HuaweiCloudClient {
  final String accessToken;
  final String clientId;
  
  static const String baseUrl = 'https://health-api.cloud.huawei.com/healthkit';

  HuaweiCloudClient({
    required this.accessToken,
    required this.clientId,
  });

  /// 读取健康数据（支持原子和统计查询）
  /// 
  /// [queryType] 查询类型：'detail'原子读取，'daily'按天统计
  Future<HealthDataResult> readHealthData({
    required HealthDataType dataType,
    required int startTime,
    required int endTime,
    String queryType = 'detail',
  }) async {
    try {
      // 映射数据类型到华为云侧API数据类型
      final huaweiDataType = _mapDataType(dataType);
      if (huaweiDataType == null) {
        return HealthDataResult(
          status: HealthDataStatus.dataTypeNotSupported,
          platform: HealthPlatform.huaweiCloud,
          message: 'Data type not supported: ${dataType.key}',
        );
      }

      debugPrint('[Cloud API] 查询类型: $queryType');

      // 根据查询类型构建不同的请求和端点
      final String endpoint;
      final Map<String, dynamic> requestBody;

      if (queryType == 'daily') {
        // 统计查询 - 使用dailyPolymerize
        endpoint = '$baseUrl/v2/sampleSet:dailyPolymerize';
        
        // 转换时间戳为日期字符串 yyyyMMdd
        final startDate = DateTime.fromMillisecondsSinceEpoch(startTime);
        final endDate = DateTime.fromMillisecondsSinceEpoch(endTime);
        final startDay = '${startDate.year}${startDate.month.toString().padLeft(2, '0')}${startDate.day.toString().padLeft(2, '0')}';
        final endDay = '${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';
        
        requestBody = {
          'dataTypes': [huaweiDataType],
          'startDay': startDay,
          'endDay': endDay,
          'timeZone': '+0800', // 使用东八区时区
        };
      } else {
        // 原子查询 - 使用polymerize
        endpoint = '$baseUrl/v2/sampleSet:polymerize';
        requestBody = {
          'polymerizeWith': [
            {'dataTypeName': huaweiDataType}
          ],
          'startTime': startTime,
          'endTime': endTime,
        };
      }

      debugPrint('[Cloud API] 请求: ${jsonEncode(requestBody)}');

      // 调用云侧API
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'x-client-id': clientId,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('[Cloud API] 响应状态: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('[Cloud API] 响应数据: ${jsonEncode(responseData)}');
        
        final List<HealthData> healthDataList;
        
        if (queryType == 'daily') {
          // 解析daily响应
          final dailyResponse = DailyPolymerizeResponse.fromJson(responseData);
          healthDataList = _convertDailyToHealthData(dailyResponse, dataType);
        } else {
          // 解析detail响应
          final polyResponse = PolymerizeResponse.fromJson(responseData);
          healthDataList = _convertToHealthData(polyResponse, dataType);
        }

        return HealthDataResult(
          status: HealthDataStatus.success,
          platform: HealthPlatform.huaweiCloud,
          data: healthDataList,
          totalCount: healthDataList.length,
        );
      } else {
        final errorBody = response.body;
        debugPrint('[Cloud API] 错误响应: $errorBody');
        return HealthDataResult(
          status: HealthDataStatus.error,
          platform: HealthPlatform.huaweiCloud,
          message: 'HTTP ${response.statusCode}: $errorBody',
        );
      }
    } catch (e) {
      debugPrint('[Cloud API] 异常: $e');
      return HealthDataResult(
        status: HealthDataStatus.error,
        platform: HealthPlatform.huaweiCloud,
        message: e.toString(),
      );
    }
  }

  /// 映射通用数据类型到华为云侧API数据类型
  String? _mapDataType(HealthDataType dataType) {
    switch (dataType) {
      case HealthDataType.steps:
        return HuaweiDataTypes.stepsDelta;
      case HealthDataType.glucose:
        return HuaweiDataTypes.bloodGlucoseInstantaneous;
      case HealthDataType.bloodPressure:
        return HuaweiDataTypes.bloodPressureInstantaneous;
      default:
        return null;
    }
  }

  /// 转换云侧API响应数据为通用健康数据格式
  /// 保留原始metadata，不做任何转换
  List<HealthData> _convertToHealthData(
    PolymerizeResponse response,
    HealthDataType dataType,
  ) {
    final healthDataList = <HealthData>[];
    final allPoints = response.allSamplePoints;

    for (final point in allPoints) {
      // 构建原始metadata，保留所有字段
      final metadata = <String, dynamic>{
        'startTime': point.startDateTime.toIso8601String(),
        'endTime': point.endDateTime.toIso8601String(),
        'dataTypeName': point.dataTypeName,
      };

      // 保留所有原始字段值
      for (final fieldValue in point.values) {
        metadata[fieldValue.fieldName] = fieldValue.value;
      }

      // 根据数据类型提取主值
      double? mainValue;
      switch (dataType) {
        case HealthDataType.steps:
          mainValue = point.stepsValue?.toDouble();
          break;
        case HealthDataType.glucose:
          mainValue = point.bloodGlucoseValue;
          break;
        case HealthDataType.bloodPressure:
          // 血压是复合数据，主值为null，数据在metadata中
          mainValue = null;
          break;
        default:
          mainValue = null;
      }

      if (mainValue != null || dataType == HealthDataType.bloodPressure) {
        healthDataList.add(HealthData(
          type: dataType,
          value: mainValue,
          unit: dataType.unit,
          timestamp: point.startDateTime.millisecondsSinceEpoch,
          platform: HealthPlatform.huaweiCloud,
          metadata: metadata,
        ));
      }
    }

    return healthDataList;
  }

  /// 转换Daily统计响应数据为通用健康数据格式
  /// 保留原始metadata，不做任何转换
  List<HealthData> _convertDailyToHealthData(
    DailyPolymerizeResponse response,
    HealthDataType dataType,
  ) {
    final healthDataList = <HealthData>[];

    for (final group in response.groups) {
      // 收集该天的所有采样点
      final allPoints = <SamplePoint>[];
      for (final sampleSet in group.sampleSets) {
        allPoints.addAll(sampleSet.samplePoints);
      }

      if (allPoints.isEmpty) continue;

      // 对于daily统计，通常每天只有一个汇总点
      for (final point in allPoints) {
        // 构建原始metadata，保留所有字段
        final metadata = <String, dynamic>{
          'date': group.date.toIso8601String().split('T')[0], // 只保留日期部分
          'dataTypeName': point.dataTypeName,
        };

        // 保留所有原始字段值（包括avg, max, min等统计值）
        for (final fieldValue in point.values) {
          metadata[fieldValue.fieldName] = fieldValue.value;
        }

        // 根据数据类型提取主值
        double? mainValue;
        switch (dataType) {
          case HealthDataType.steps:
            // 步数使用总和
            mainValue = point.stepsValue?.toDouble();
            break;
          case HealthDataType.glucose:
            // 血糖使用平均值，从字段中提取
            for (final fieldValue in point.values) {
              if (fieldValue.fieldName == FieldNames.avg) {
                mainValue = fieldValue.value as double?;
                break;
              }
            }
            break;
          case HealthDataType.bloodPressure:
            // 血压是复合数据，主值为null，数据在metadata中
            mainValue = null;
            break;
          default:
            mainValue = null;
        }

        // 使用当天的0点作为时间戳
        final dayTimestamp = DateTime(
          group.date.year,
          group.date.month,
          group.date.day,
        ).millisecondsSinceEpoch;

        healthDataList.add(HealthData(
          type: dataType,
          value: mainValue,
          unit: dataType.unit,
          timestamp: dayTimestamp,
          platform: HealthPlatform.huaweiCloud,
          metadata: metadata,
        ));
      }
    }

    return healthDataList;
  }
}

