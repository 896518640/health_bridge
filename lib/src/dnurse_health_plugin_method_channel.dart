import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dnurse_health_plugin_platform_interface.dart';
import 'models/health_data.dart';
import 'models/health_platform.dart';

/// DnurseHealthPlugin的MethodChannel实现
class MethodChannelDnurseHealthPlugin extends DnurseHealthPluginPlatform {
  /// 用于与原生代码通信的方法通道
  @visibleForTesting
  final methodChannel = const MethodChannel('dnurse_health_plugin');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<List<HealthPlatform>> getAvailableHealthPlatforms() async {
    try {
      final result = await methodChannel.invokeMethod<List<dynamic>>('getAvailableHealthPlatforms');
      if (result == null) return [];

      return result
          .cast<String>()
          .map((platformKey) => HealthPlatform.values.firstWhere(
                (platform) => platform.key == platformKey,
                orElse: () => HealthPlatform.samsungHealth,
              ))
          .toList();
    } catch (e) {
      debugPrint('Error getting available health platforms: $e');
      return [];
    }
  }

  @override
  Future<HealthDataResult> initializeHealthPlatform(HealthPlatform platform) async {
    try {
      final result = await methodChannel.invokeMethod(
        'initializeHealthPlatform',
        {'platform': platform.key},
      );

      if (result == null) {
        return HealthDataResult(
          status: HealthDataStatus.error,
          platform: platform,
          message: 'No result returned from platform',
        );
      }

      // 安全转换到Map<String, dynamic>
      final resultMap = Map<String, dynamic>.from(result as Map);
      return _parseHealthDataResult(resultMap, platform);
    } catch (e) {
      debugPrint('Error initializing health platform ${platform.key}: $e');
      return HealthDataResult(
        status: HealthDataStatus.error,
        platform: platform,
        message: e.toString(),
      );
    }
  }



  @override
  Future<HealthDataResult> readStepCount({
    required HealthPlatform platform,
  }) async {
    try {
      final result = await methodChannel.invokeMethod(
        'readStepCount',
        {'platform': platform.key},
      );

      if (result == null) {
        return HealthDataResult(
          status: HealthDataStatus.error,
          platform: platform,
          data: [],
        );
      }

      final resultMap = Map<String, dynamic>.from(result as Map);
      return _parseHealthDataResult(resultMap, platform);
    } catch (e) {
      debugPrint('Error reading step count: $e');
      return HealthDataResult(
        status: HealthDataStatus.error,
        platform: platform,
        message: e.toString(),
      );
    }
  }

  @override
  Future<HealthDataResult> readStepCountForDate({
    required DateTime date,
    required HealthPlatform platform,
  }) async {
    try {
      final result = await methodChannel.invokeMethod(
        'readStepCountForDate',
        {
          'date': date.millisecondsSinceEpoch,
          'platform': platform.key,
        },
      );

      if (result == null) {
        return HealthDataResult(
          status: HealthDataStatus.error,
          platform: platform,
          data: [],
        );
      }

      final resultMap = Map<String, dynamic>.from(result as Map);
      return _parseHealthDataResult(resultMap, platform);
    } catch (e) {
      debugPrint('Error reading step count for date: $e');
      return HealthDataResult(
        status: HealthDataStatus.error,
        platform: platform,
        message: e.toString(),
      );
    }
  }

  @override
  Future<HealthDataResult> readStepCountForDateRange({
    required DateTime startDate,
    required DateTime endDate,
    required HealthPlatform platform,
  }) async {
    try {
      final result = await methodChannel.invokeMethod(
        'readStepCountForDateRange',
        {
          'startDate': startDate.millisecondsSinceEpoch,
          'endDate': endDate.millisecondsSinceEpoch,
          'platform': platform.key,
        },
      );

      if (result == null) {
        return HealthDataResult(
          status: HealthDataStatus.error,
          platform: platform,
          data: [],
        );
      }

      final resultMap = Map<String, dynamic>.from(result as Map);
      return _parseHealthDataResult(resultMap, platform);
    } catch (e) {
      debugPrint('Error reading step count for date range: $e');
      return HealthDataResult(
        status: HealthDataStatus.error,
        platform: platform,
        message: e.toString(),
      );
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await methodChannel.invokeMethod<void>('disconnect');
    } catch (e) {
      debugPrint('Error disconnecting health platforms: $e');
    }
  }

  /// 解析原生返回的结果
  HealthDataResult _parseHealthDataResult(
    Map<String, dynamic> result,
    HealthPlatform platform,
  ) {
    try {
      // 处理成功状态 - 兼容多种成功状态格式
      if (result['success'] == true || 
          result['status'] == 'connected' || 
          result['status'] == 'success') {
        final dataList = <HealthData>[];
        
        // 解析单个数据项
        if (result['data'] != null) {
          final data = result['data'];
          if (data is Map) {
            // 单个数据项 - 安全转换
            final dataMap = Map<String, dynamic>.from(data);
            dataList.add(HealthData.fromJson({
              ...dataMap,
              'platform': platform.key,
            }));
          } else if (data is List) {
            // 多个数据项
            for (final item in data) {
              if (item is Map) {
                final itemMap = Map<String, dynamic>.from(item);
                dataList.add(HealthData.fromJson({
                  ...itemMap,
                  'platform': platform.key,
                }));
              }
            }
          }
        }

        return HealthDataResult(
          status: HealthDataStatus.success,
          platform: platform,
          data: dataList,
          message: result['message']?.toString(),
          totalCount: (result['count'] as num?)?.toInt() ?? 
                      (result['totalSteps'] as num?)?.toInt() ?? 
                      dataList.length,
        );
      } else {
        // 处理错误状态
        return HealthDataResult(
          status: HealthDataStatus.error,
          platform: platform,
          message: result['message']?.toString() ?? 'Unknown error',
        );
      }
    } catch (e) {
      debugPrint('Error parsing health data result: $e');
      return HealthDataResult(
        status: HealthDataStatus.error,
        platform: platform,
        message: 'Failed to parse result: $e',
      );
    }
  }
}