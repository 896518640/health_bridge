import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'health_bridge_platform_interface.dart';
import 'models/health_data.dart';
import 'models/health_platform.dart';

/// HealthBridge的MethodChannel实现
class MethodChannelHealthBridge extends HealthBridgePlatform {
  /// 用于与原生代码通信的方法通道
  @visibleForTesting
  final methodChannel = const MethodChannel('health_bridge');

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
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // 处理日期参数逻辑
      final now = DateTime.now();
      final effectiveStartDate = startDate ?? DateTime(now.year, now.month, now.day);
      
      DateTime effectiveEndDate;
      if (endDate != null) {
        effectiveEndDate = endDate;
      } else if (startDate != null) {
        // 如果只提供了startDate，读取该日的结束时间
        effectiveEndDate = DateTime(startDate.year, startDate.month, startDate.day, 23, 59, 59, 999);
      } else {
        // 如果都没提供，读取今日的结束时间
        effectiveEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      }

      // 判断是单日查询还是范围查询
      final isSameDay = effectiveStartDate.year == effectiveEndDate.year &&
          effectiveStartDate.month == effectiveEndDate.month &&
          effectiveStartDate.day == effectiveEndDate.day;

      final Map<String, dynamic> arguments = {
        'platform': platform.key,
      };

      // 统一使用 readStepCount 方法，通过参数区分不同场景
      if (startDate != null) {
        arguments['startDate'] = effectiveStartDate.millisecondsSinceEpoch;
      }
      if (endDate != null && !isSameDay) {
        arguments['endDate'] = effectiveEndDate.millisecondsSinceEpoch;
      }

      final result = await methodChannel.invokeMethod('readStepCount', arguments);

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

        final calculatedTotalCount = (result['totalSteps'] as num?)?.toInt() ?? 
                      (result['count'] as num?)?.toInt() ?? 
                      dataList.length;
        
        return HealthDataResult(
          status: HealthDataStatus.success,
          platform: platform,
          data: dataList,
          message: result['message']?.toString(),
          totalCount: calculatedTotalCount,
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