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

  // ============================================
  // 授权管理相关API（新增）
  // ============================================

  /// 查询隐私授权状态
  ///
  /// 检查用户是否在华为运动健康App中开启了数据共享授权。
  ///
  /// 使用场景：
  /// - 在调用其他健康数据API之前，先检查用户是否已授权
  /// - 如果未授权，引导用户去华为运动健康App开启授权
  ///
  /// 返回值：
  /// - [PrivacyAuthStatus.authorized] (1)：已授权，可以访问健康数据
  /// - [PrivacyAuthStatus.notAuthorized] (2)：未授权，需要引导用户开启
  /// - [PrivacyAuthStatus.notHealthUser] (3)：非华为运动健康App用户
  ///
  /// 示例：
  /// ```dart
  /// final status = await client.checkPrivacyAuthStatus();
  ///
  /// if (status.isAuthorized) {
  ///   // 已授权，可以访问健康数据
  /// } else if (status == PrivacyAuthStatus.notAuthorized) {
  ///   // 引导用户去华为运动健康App开启授权
  /// } else {
  ///   // 用户没有安装华为运动健康App
  /// }
  /// ```
  Future<PrivacyAuthStatus> checkPrivacyAuthStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/v2/profile/privacyRecords'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $accessToken',
          'x-client-id': clientId,
        },
      );

      debugPrint('[Privacy Auth] 响应状态: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as List;
        if (responseData.isNotEmpty) {
          final opinion = responseData[0]['opinion'] as int;
          final status = PrivacyAuthStatus.fromOpinion(opinion);
          debugPrint('[Privacy Auth] 授权状态: ${status.description}');
          return status;
        }
      }

      debugPrint('[Privacy Auth] 错误: ${response.body}');
      return PrivacyAuthStatus.notAuthorized;
    } catch (e) {
      debugPrint('[Privacy Auth] 异常: $e');
      return PrivacyAuthStatus.notAuthorized;
    }
  }

  /// 查询用户授权权限
  ///
  /// 获取用户授权给指定应用的所有健康数据权限详情。
  ///
  /// 参数：
  /// - [appId]：应用ID（第三方自身的应用标识，通常就是 clientId）
  /// - [lang]：语言代码，默认 'zh-cn'（中文），可选 'en-US'（英文）
  ///
  /// 返回：
  /// - [UserConsentInfo]：包含授权的权限列表、授权时间、应用信息等
  ///
  /// 使用场景：
  /// - 在应用设置页面展示用户已授权的所有健康数据权限
  /// - 验证 OAuth 授权是否成功获取了预期的 scopes
  /// - 调试和测试授权流程
  ///
  /// 示例：
  /// ```dart
  /// final consentInfo = await client.getUserConsents(
  ///   appId: '108913819',
  ///   lang: 'zh-cn',
  /// );
  ///
  /// print('应用名称: ${consentInfo.appName}');
  /// print('授权时间: ${consentInfo.authTime}');
  /// print('已授权权限:');
  /// consentInfo.scopeDescriptions.forEach((scope, desc) {
  ///   print('  $scope: $desc');
  /// });
  ///
  /// // 检查是否有睡眠数据权限
  /// if (consentInfo.hasScope('https://www.huawei.com/healthkit/sleep.read')) {
  ///   print('有睡眠数据读取权限');
  /// }
  /// ```
  Future<UserConsentInfo> getUserConsents({
    required String appId,
    String lang = 'zh-cn',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/v2/consents/$appId?lang=$lang'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $accessToken',
          'x-client-id': clientId,
        },
      );

      debugPrint('[User Consents] 响应状态: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('[User Consents] 响应数据: ${jsonEncode(responseData)}');
        final consentInfo = UserConsentInfo.fromJson(responseData);
        debugPrint('[User Consents] 解析成功: $consentInfo');
        return consentInfo;
      } else {
        final errorBody = response.body;
        debugPrint('[User Consents] 错误: $errorBody');
        throw Exception('Failed to get user consents: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[User Consents] 异常: $e');
      rethrow;
    }
  }

  /// 取消授权
  ///
  /// 取消用户对该应用的全部健康数据访问权限。
  ///
  /// 参数：
  /// - [appId]：应用ID（第三方自身的应用标识，通常就是 clientId）
  /// - [deleteDataImmediately]：是否立即删除该应用创建的数据
  ///   - `false`（默认）：给用户3天反悔期，如果3天内不重新授权，系统会自动删除数据
  ///   - `true`：立即删除该应用创建的所有数据
  ///
  /// 返回：
  /// - `true`：取消授权成功
  /// - `false`：取消授权失败
  ///
  /// ⚠️ 重要提示：
  /// - 建议使用默认值 `deleteDataImmediately = false`，给用户反悔的机会
  /// - 调用此接口后，应同时清除本地存储的 access_token 和 refresh_token
  /// - 用户如需继续使用，需要重新进行 OAuth 授权流程
  ///
  /// 使用场景：
  /// - 用户在设置中主动撤销授权
  /// - 用户注销账号时清理授权数据
  /// - 应用卸载前清理授权（可选）
  ///
  /// 示例：
  /// ```dart
  /// // 取消授权（保留数据3天）
  /// final success = await client.revokeConsent(
  ///   appId: '108913819',
  ///   deleteDataImmediately: false,
  /// );
  ///
  /// if (success) {
  ///   // 清除本地存储的 token
  ///   await secureStorage.delete(key: 'access_token');
  ///   await secureStorage.delete(key: 'refresh_token');
  ///
  ///   // 提示用户
  ///   showDialog(
  ///     context: context,
  ///     builder: (context) => AlertDialog(
  ///       title: Text('授权已取消'),
  ///       content: Text('如需继续使用，请在3天内重新授权。'),
  ///     ),
  ///   );
  /// }
  /// ```
  Future<bool> revokeConsent({
    required String appId,
    bool deleteDataImmediately = false,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/v2/consents/$appId?deleteData=$deleteDataImmediately'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $accessToken',
          'x-client-id': clientId,
        },
      );

      debugPrint('[Revoke Consent] 响应状态: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('[Revoke Consent] ✅ 授权已取消');
        return true;
      } else {
        debugPrint('[Revoke Consent] ❌ 取消授权失败: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[Revoke Consent] 异常: $e');
      return false;
    }
  }
}

