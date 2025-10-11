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

  // ========== 权限管理实现 ==========

  @override
  Future<Map<HealthDataType, HealthPermissionStatus>> checkPermissions({
    required HealthPlatform platform,
    required List<HealthDataType> dataTypes,
    required HealthDataOperation operation,
  }) async {
    try {
      final result = await methodChannel.invokeMethod(
        'checkPermissions',
        {
          'platform': platform.key,
          'dataTypes': dataTypes.map((t) => t.key).toList(),
          'operation': operation.key,
        },
      );

      if (result == null) return {};

      final resultMap = Map<String, dynamic>.from(result as Map);
      final permissionsMap = Map<String, dynamic>.from(resultMap['permissions'] as Map? ?? {});

      final permissions = <HealthDataType, HealthPermissionStatus>{};
      for (final dataType in dataTypes) {
        final statusKey = permissionsMap[dataType.key] as String?;
        if (statusKey != null) {
          permissions[dataType] = HealthPermissionStatus.values.firstWhere(
            (s) => s.key == statusKey,
            orElse: () => HealthPermissionStatus.notDetermined,
          );
        }
      }

      return permissions;
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      return {};
    }
  }

  @override
  Future<HealthDataResult> requestPermissions({
    required HealthPlatform platform,
    required List<HealthDataType> dataTypes,
    required List<HealthDataOperation> operations,
    String? reason,
  }) async {
    try {
      final result = await methodChannel.invokeMethod(
        'requestPermissions',
        {
          'platform': platform.key,
          'dataTypes': dataTypes.map((t) => t.key).toList(),
          'operations': operations.map((o) => o.key).toList(),
          if (reason != null) 'reason': reason,
        },
      );

      if (result == null) {
        return HealthDataResult(
          status: HealthDataStatus.error,
          platform: platform,
          message: 'No result returned from platform',
        );
      }

      final resultMap = Map<String, dynamic>.from(result as Map);
      return _parseHealthDataResult(resultMap, platform);
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return HealthDataResult(
        status: HealthDataStatus.error,
        platform: platform,
        message: e.toString(),
      );
    }
  }

  @override
  Future<HealthDataResult> revokeAllAuthorizations({
    required HealthPlatform platform,
  }) async {
    try {
      final result = await methodChannel.invokeMethod(
        'revokeAllAuthorizations',
        {
          'platform': platform.key,
        },
      );

      if (result == null) {
        return HealthDataResult(
          status: HealthDataStatus.error,
          platform: platform,
          message: 'No result returned from platform',
        );
      }

      final resultMap = Map<String, dynamic>.from(result as Map);
      return _parseHealthDataResult(resultMap, platform);
    } catch (e) {
      debugPrint('Error revoking all authorizations: $e');
      return HealthDataResult(
        status: HealthDataStatus.error,
        platform: platform,
        message: e.toString(),
      );
    }
  }

  @override
  Future<HealthDataResult> revokeAuthorizations({
    required HealthPlatform platform,
    required List<HealthDataType> dataTypes,
    required List<HealthDataOperation> operations,
  }) async {
    try {
      final result = await methodChannel.invokeMethod(
        'revokeAuthorizations',
        {
          'platform': platform.key,
          'dataTypes': dataTypes.map((t) => t.key).toList(),
          'operations': operations.map((o) => o.key).toList(),
        },
      );

      if (result == null) {
        return HealthDataResult(
          status: HealthDataStatus.error,
          platform: platform,
          message: 'No result returned from platform',
        );
      }

      final resultMap = Map<String, dynamic>.from(result as Map);
      return _parseHealthDataResult(resultMap, platform);
    } catch (e) {
      debugPrint('Error revoking authorizations: $e');
      return HealthDataResult(
        status: HealthDataStatus.error,
        platform: platform,
        message: e.toString(),
      );
    }
  }

  // ========== 平台能力查询实现 ==========

  @override
  Future<List<HealthDataType>> getSupportedDataTypes({
    required HealthPlatform platform,
    HealthDataOperation? operation,
  }) async {
    try {
      final result = await methodChannel.invokeMethod<List<dynamic>>(
        'getSupportedDataTypes',
        {'platform': platform.key},
      );

      if (result == null) return super.getSupportedDataTypes(platform: platform, operation: operation);

      final supportedKeys = result.cast<String>();
      var supportedTypes = supportedKeys
          .map((key) => HealthDataType.values.firstWhere(
                (t) => t.key == key,
                orElse: () => HealthDataType.steps, // 默认值
              ))
          .toList();

      // 如果指定了操作类型，进一步过滤
      if (operation != null) {
        supportedTypes = supportedTypes.where((type) {
          return platform.supports(type, operation: operation);
        }).toList();
      }

      return supportedTypes;
    } catch (e) {
      debugPrint('Error getting supported data types: $e');
      return super.getSupportedDataTypes(platform: platform, operation: operation);
    }
  }

  @override
  Future<bool> isDataTypeSupported({
    required HealthPlatform platform,
    required HealthDataType dataType,
    required HealthDataOperation operation,
  }) async {
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'isDataTypeSupported',
        {
          'platform': platform.key,
          'dataType': dataType.key,
          'operation': operation.key,
        },
      );

      return result ?? super.isDataTypeSupported(platform: platform, dataType: dataType, operation: operation);
    } catch (e) {
      debugPrint('Error checking data type support: $e');
      return super.isDataTypeSupported(platform: platform, dataType: dataType, operation: operation);
    }
  }

  @override
  Future<List<PlatformCapability>> getPlatformCapabilities({
    required HealthPlatform platform,
  }) async {
    try {
      final result = await methodChannel.invokeMethod<List<dynamic>>(
        'getPlatformCapabilities',
        {'platform': platform.key},
      );

      if (result == null) return super.getPlatformCapabilities(platform: platform);

      final capabilities = result.map((item) {
        final capMap = Map<String, dynamic>.from(item as Map);
        final dataTypeKey = capMap['dataType'] as String;
        final dataType = HealthDataType.values.firstWhere(
          (t) => t.key == dataTypeKey,
          orElse: () => HealthDataType.steps,
        );

        return PlatformCapability(
          dataType: dataType,
          canRead: capMap['canRead'] as bool? ?? false,
          canWrite: capMap['canWrite'] as bool? ?? false,
          requiresSpecialPermission: capMap['requiresSpecialPermission'] as bool? ?? false,
          notes: capMap['notes'] as String?,
        );
      }).toList();

      return capabilities;
    } catch (e) {
      debugPrint('Error getting platform capabilities: $e');
      return super.getPlatformCapabilities(platform: platform);
    }
  }

  // ========== 统一数据读写实现 ==========

  @override
  Future<HealthDataResult> readHealthData({
    required HealthPlatform platform,
    required HealthDataType dataType,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      final Map<String, dynamic> arguments = {
        'platform': platform.key,
        'dataType': dataType.key,
      };

      if (startDate != null) {
        arguments['startDate'] = startDate.millisecondsSinceEpoch.toDouble();
      }
      if (endDate != null) {
        arguments['endDate'] = endDate.millisecondsSinceEpoch.toDouble();
      }
      if (limit != null) {
        arguments['limit'] = limit;
      }

      final result = await methodChannel.invokeMethod('readHealthData', arguments);

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
      debugPrint('Error reading health data: $e');
      return HealthDataResult(
        status: HealthDataStatus.error,
        platform: platform,
        message: e.toString(),
      );
    }
  }

  @override
  Future<HealthDataResult> writeHealthData({
    required HealthPlatform platform,
    required HealthData data,
  }) async {
    try {
      final result = await methodChannel.invokeMethod(
        'writeHealthData',
        {
          'platform': platform.key,
          'data': data.toJson(),
        },
      );

      if (result == null) {
        return HealthDataResult(
          status: HealthDataStatus.error,
          platform: platform,
          message: 'No result returned from platform',
        );
      }

      final resultMap = Map<String, dynamic>.from(result as Map);
      return _parseHealthDataResult(resultMap, platform);
    } catch (e) {
      debugPrint('Error writing health data: $e');
      return HealthDataResult(
        status: HealthDataStatus.error,
        platform: platform,
        message: e.toString(),
      );
    }
  }

  @override
  Future<HealthDataResult> writeBatchHealthData({
    required HealthPlatform platform,
    required List<HealthData> dataList,
  }) async {
    try {
      // 暂时使用循环写入实现批量写入
      // 未来可以优化为原生层的批量操作
      for (final data in dataList) {
        final result = await writeHealthData(platform: platform, data: data);
        if (!result.isSuccess) {
          return result; // 遇到第一个失败就返回
        }
      }

      return HealthDataResult(
        status: HealthDataStatus.success,
        platform: platform,
        message: 'Successfully wrote ${dataList.length} records',
      );
    } catch (e) {
      debugPrint('Error writing batch health data: $e');
      return HealthDataResult(
        status: HealthDataStatus.error,
        platform: platform,
        message: e.toString(),
      );
    }
  }

  /// 深度转换 Map，处理嵌套的 Map 和 List
  Map<String, dynamic> _deepConvertMap(Map<dynamic, dynamic> map) {
    return map.map((key, value) {
      dynamic convertedValue = value;
      if (value is Map) {
        convertedValue = _deepConvertMap(value);
      } else if (value is List) {
        convertedValue = value.map((item) {
          if (item is Map) {
            return _deepConvertMap(item);
          }
          return item;
        }).toList();
      }
      return MapEntry(key.toString(), convertedValue);
    });
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
            // 单个数据项 - 深度转换
            dataList.add(HealthData.fromJson({
              ..._deepConvertMap(data),
              'platform': platform.key,
            }));
          } else if (data is List) {
            // 多个数据项
            for (final item in data) {
              if (item is Map) {
                dataList.add(HealthData.fromJson({
                  ..._deepConvertMap(item),
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