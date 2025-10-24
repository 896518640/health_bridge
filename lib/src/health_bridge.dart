import 'health_bridge_platform_interface.dart';
import 'health_bridge_method_channel.dart';
import 'models/health_data.dart';
import 'models/health_platform.dart';

/// HealthBridge的主类，提供多平台健康数据集成功能
class HealthBridge {
  /// 获取平台版本信息
  static Future<String?> getPlatformVersion() {
    return HealthBridgePlatform.instance.getPlatformVersion();
  }

  /// 获取当前设备支持的健康平台列表
  /// 
  /// 返回当前设备上可用的健康平台，如Samsung Health、Apple Health等
  static Future<List<HealthPlatform>> getAvailableHealthPlatforms() {
    return HealthBridgePlatform.instance.getAvailableHealthPlatforms();
  }

  /// 初始化健康平台
  /// 
  /// [platform] 要初始化的健康平台
  /// [dataTypes] 必需：需要请求权限的数据类型列表（如 [HealthDataType.glucose, HealthDataType.steps]）
  /// [operations] 必需：需要请求的操作类型列表（如 [HealthDataOperation.read, HealthDataOperation.write]）
  /// 
  /// ⚠️ 注意：不再提供默认数据类型，开发者必须明确指定需要的数据类型，符合最小权限原则
  /// 
  /// 使用示例：
  /// ```dart
  /// // Apple Health: 请求血糖、步数、体重的读写权限
  /// await HealthBridge.initializeHealthPlatform(
  ///   HealthPlatform.appleHealth,
  ///   dataTypes: [
  ///     HealthDataType.glucose,
  ///     HealthDataType.steps,
  ///     HealthDataType.weight,
  ///   ],
  ///   operations: [HealthDataOperation.read, HealthDataOperation.write],
  /// );
  /// 
  /// // 华为健康: 只请求读取权限
  /// await HealthBridge.initializeHealthPlatform(
  ///   HealthPlatform.huaweiHealth,
  ///   dataTypes: [
  ///     HealthDataType.glucose,
  ///     HealthDataType.bloodPressure,
  ///   ],
  ///   operations: [HealthDataOperation.read],
  /// );
  /// ```
  /// 
  /// 返回初始化结果，包含连接状态和权限信息
  static Future<HealthDataResult> initializeHealthPlatform(
    HealthPlatform platform, {
    required List<HealthDataType> dataTypes,
    required List<HealthDataOperation> operations,
  }) {
    return HealthBridgePlatform.instance.initializeHealthPlatform(
      platform,
      dataTypes: dataTypes,
      operations: operations,
    );
  }



  /// 从指定健康平台读取步数数据
  /// 
  /// [platform] 数据源健康平台
  /// [startDate] 开始日期，为null时读取今日数据
  /// [endDate] 结束日期，为null时读取startDate当日数据
  /// 
  /// 使用示例：
  /// ```dart
  /// // 读取今日步数
  /// await HealthBridge.readStepCount(platform: platform);
  /// 
  /// // 读取指定日期步数
  /// await HealthBridge.readStepCount(platform: platform, startDate: date);
  /// 
  /// // 读取日期范围步数
  /// await HealthBridge.readStepCount(
  ///   platform: platform, 
  ///   startDate: startDate, 
  ///   endDate: endDate
  /// );
  /// ```
  static Future<HealthDataResult> readStepCount({
    required HealthPlatform platform,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return HealthBridgePlatform.instance.readStepCount(
      platform: platform,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// 断开所有健康平台连接
  /// 
  /// 用于清理资源，通常在应用退出时调用
  static Future<void> disconnect() {
    return HealthBridgePlatform.instance.disconnect();
  }

  // 便利方法

  /// 检查Samsung Health是否可用
  static Future<bool> isSamsungHealthAvailable() async {
    final platforms = await getAvailableHealthPlatforms();
    return platforms.contains(HealthPlatform.samsungHealth);
  }

  /// 检查Apple Health是否可用  
  static Future<bool> isAppleHealthAvailable() async {
    final platforms = await getAvailableHealthPlatforms();
    return platforms.contains(HealthPlatform.appleHealth);
  }

  /// 自动选择最佳可用健康平台
  static Future<HealthPlatform?> getPreferredHealthPlatform() async {
    final platforms = await getAvailableHealthPlatforms();
    if (platforms.isEmpty) return null;

    // 优先级: Samsung Health > Apple Health > Google Fit > Huawei Health
    const preferenceOrder = [
      HealthPlatform.samsungHealth,
      HealthPlatform.appleHealth,
      HealthPlatform.googleFit,
      HealthPlatform.huaweiHealth,
    ];

    for (final preferred in preferenceOrder) {
      if (platforms.contains(preferred)) {
        return preferred;
      }
    }

    return platforms.first;
  }

  /// 初始化最佳可用健康平台
  /// 
  /// [dataTypes] 必需：需要请求权限的数据类型列表
  /// [operations] 必需：需要请求的操作类型列表
  static Future<HealthDataResult?> initializePreferredPlatform({
    required List<HealthDataType> dataTypes,
    required List<HealthDataOperation> operations,
  }) async {
    final platform = await getPreferredHealthPlatform();
    if (platform == null) return null;

    return await initializeHealthPlatform(
      platform,
      dataTypes: dataTypes,
      operations: operations,
    );
  }

  // ========== 权限管理 ==========

  /// 检查指定数据类型的权限状态
  ///
  /// [platform] 健康平台
  /// [dataTypes] 要检查的数据类型列表
  /// [operation] 操作类型（读/写）
  ///
  /// 返回每个数据类型对应的权限状态
  ///
  /// 使用示例：
  /// ```dart
  /// final permissions = await HealthBridge.checkPermissions(
  ///   platform: platform,
  ///   dataTypes: [HealthDataType.steps, HealthDataType.heartRate],
  ///   operation: HealthDataOperation.read,
  /// );
  ///
  /// if (permissions[HealthDataType.steps]?.isGranted ?? false) {
  ///   // 有权限，可以读取步数
  /// }
  /// ```
  static Future<Map<HealthDataType, HealthPermissionStatus>> checkPermissions({
    required HealthPlatform platform,
    required List<HealthDataType> dataTypes,
    required HealthDataOperation operation,
  }) {
    return HealthBridgePlatform.instance.checkPermissions(
      platform: platform,
      dataTypes: dataTypes,
      operation: operation,
    );
  }

  /// 申请指定数据类型的权限
  ///
  /// [platform] 健康平台
  /// [dataTypes] 要申请的数据类型列表
  /// [operations] 操作类型列表（可以同时申请读写）
  /// [reason] 申请理由（可选，用于UI展示）
  ///
  /// 返回申请结果
  ///
  /// 使用示例：
  /// ```dart
  /// final result = await HealthBridge.requestPermissions(
  ///   platform: platform,
  ///   dataTypes: [HealthDataType.steps, HealthDataType.heartRate],
  ///   operations: [HealthDataOperation.read],
  ///   reason: '读取运动数据',
  /// );
  ///
  /// if (result.isSuccess) {
  ///   // 权限申请成功
  /// }
  /// ```
  static Future<HealthDataResult> requestPermissions({
    required HealthPlatform platform,
    required List<HealthDataType> dataTypes,
    required List<HealthDataOperation> operations,
    String? reason,
  }) {
    return HealthBridgePlatform.instance.requestPermissions(
      platform: platform,
      dataTypes: dataTypes,
      operations: operations,
      reason: reason,
    );
  }

  /// 按权限组申请权限（便利方法）
  ///
  /// [platform] 健康平台
  /// [group] 权限组
  /// [operations] 操作类型列表
  /// [reason] 申请理由
  ///
  /// 使用示例：
  /// ```dart
  /// // 申请活动数据权限（步数、距离、卡路里等）
  /// final result = await HealthBridge.requestPermissionGroup(
  ///   platform: platform,
  ///   group: HealthPermissionGroup.activity,
  ///   operations: [HealthDataOperation.read],
  ///   reason: '读取活动数据',
  /// );
  /// ```
  static Future<HealthDataResult> requestPermissionGroup({
    required HealthPlatform platform,
    required HealthPermissionGroup group,
    required List<HealthDataOperation> operations,
    String? reason,
  }) {
    return HealthBridgePlatform.instance.requestPermissionGroup(
      platform: platform,
      group: group,
      operations: operations,
      reason: reason,
    );
  }

  /// 取消全部授权
  ///
  /// [platform] 健康平台
  ///
  /// 返回取消结果
  ///
  /// 使用示例：
  /// ```dart
  /// final result = await HealthBridge.revokeAllAuthorizations(
  ///   platform: platform,
  /// );
  ///
  /// if (result.isSuccess) {
  ///   // 全部授权已取消
  /// }
  /// ```
  static Future<HealthDataResult> revokeAllAuthorizations({
    required HealthPlatform platform,
  }) {
    return HealthBridgePlatform.instance.revokeAllAuthorizations(
      platform: platform,
    );
  }

  /// 取消部分授权（指定数据类型）
  ///
  /// [platform] 健康平台
  /// [dataTypes] 要取消授权的数据类型列表
  /// [operations] 操作类型列表
  ///
  /// 返回取消结果
  ///
  /// 使用示例：
  /// ```dart
  /// final result = await HealthBridge.revokeAuthorizations(
  ///   platform: platform,
  ///   dataTypes: [HealthDataType.steps, HealthDataType.glucose],
  ///   operations: [HealthDataOperation.read, HealthDataOperation.write],
  /// );
  ///
  /// if (result.isSuccess) {
  ///   // 指定数据类型的授权已取消
  /// }
  /// ```
  static Future<HealthDataResult> revokeAuthorizations({
    required HealthPlatform platform,
    required List<HealthDataType> dataTypes,
    required List<HealthDataOperation> operations,
  }) {
    return HealthBridgePlatform.instance.revokeAuthorizations(
      platform: platform,
      dataTypes: dataTypes,
      operations: operations,
    );
  }

  // ========== 平台能力查询 ==========

  /// 获取指定平台支持的所有数据类型
  ///
  /// [platform] 健康平台
  /// [operation] 操作类型（可选，不指定则返回所有）
  ///
  /// 返回该平台支持的数据类型列表
  ///
  /// 使用示例：
  /// ```dart
  /// // 获取所有支持的数据类型
  /// final allTypes = await HealthBridge.getSupportedDataTypes(
  ///   platform: platform,
  /// );
  ///
  /// // 获取支持读取的数据类型
  /// final readableTypes = await HealthBridge.getSupportedDataTypes(
  ///   platform: platform,
  ///   operation: HealthDataOperation.read,
  /// );
  /// ```
  static Future<List<HealthDataType>> getSupportedDataTypes({
    required HealthPlatform platform,
    HealthDataOperation? operation,
  }) {
    return HealthBridgePlatform.instance.getSupportedDataTypes(
      platform: platform,
      operation: operation,
    );
  }

  /// 检查指定平台是否支持某个数据类型
  ///
  /// [platform] 健康平台
  /// [dataType] 数据类型
  /// [operation] 操作类型
  ///
  /// 返回是否支持
  ///
  /// 使用示例：
  /// ```dart
  /// final supported = await HealthBridge.isDataTypeSupported(
  ///   platform: platform,
  ///   dataType: HealthDataType.glucose,
  ///   operation: HealthDataOperation.write,
  /// );
  ///
  /// if (supported) {
  ///   // 该平台支持写入血糖数据
  /// }
  /// ```
  static Future<bool> isDataTypeSupported({
    required HealthPlatform platform,
    required HealthDataType dataType,
    required HealthDataOperation operation,
  }) {
    return HealthBridgePlatform.instance.isDataTypeSupported(
      platform: platform,
      dataType: dataType,
      operation: operation,
    );
  }

  /// 获取指定平台的详细能力信息
  ///
  /// [platform] 健康平台
  ///
  /// 返回能力列表（包含读写权限、特殊说明等）
  ///
  /// 使用示例：
  /// ```dart
  /// final capabilities = await HealthBridge.getPlatformCapabilities(
  ///   platform: platform,
  /// );
  ///
  /// for (final cap in capabilities) {
  ///   print('${cap.dataType.displayName}: 读=${cap.canRead}, 写=${cap.canWrite}');
  ///   if (cap.notes != null) {
  ///     print('  注意: ${cap.notes}');
  ///   }
  /// }
  /// ```
  static Future<List<PlatformCapability>> getPlatformCapabilities({
    required HealthPlatform platform,
  }) {
    return HealthBridgePlatform.instance.getPlatformCapabilities(
      platform: platform,
    );
  }

  // ========== 统一数据读写接口 ==========

  /// 读取健康数据（通用方法）
  ///
  /// [platform] 数据源健康平台
  /// [dataType] 数据类型
  /// [startDate] 开始日期
  /// [endDate] 结束日期
  /// [limit] 数据条数限制（可选）
  /// [queryType] 查询类型（可选）：
  ///   - 'detail'（默认）：详情查询，返回所有原始数据记录
  ///   - 'statistics'：聚合查询，返回按时间段统计的数据
  ///
  /// 使用示例：
  /// ```dart
  /// // 读取最近7天的步数详情
  /// final result = await HealthBridge.readHealthData(
  ///   platform: platform,
  ///   dataType: HealthDataType.steps,
  ///   startDate: DateTime.now().subtract(Duration(days: 7)),
  ///   endDate: DateTime.now(),
  /// );
  ///
  /// // 读取最近7天的每日步数统计
  /// final statsResult = await HealthBridge.readHealthData(
  ///   platform: platform,
  ///   dataType: HealthDataType.steps,
  ///   startDate: DateTime.now().subtract(Duration(days: 7)),
  ///   endDate: DateTime.now(),
  ///   queryType: 'statistics',
  /// );
  /// ```
  static Future<HealthDataResult> readHealthData({
    required HealthPlatform platform,
    required HealthDataType dataType,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    String? queryType,
  }) {
    return HealthBridgePlatform.instance.readHealthData(
      platform: platform,
      dataType: dataType,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
      queryType: queryType,
    );
  }

  /// 批量读取多种健康数据
  ///
  /// [platform] 数据源健康平台
  /// [dataTypes] 数据类型列表
  /// [startDate] 开始日期
  /// [endDate] 结束日期
  ///
  /// 使用示例：
  /// ```dart
  /// final results = await HealthBridge.readMultipleHealthData(
  ///   platform: platform,
  ///   dataTypes: [
  ///     HealthDataType.steps,
  ///     HealthDataType.heartRate,
  ///     HealthDataType.weight,
  ///   ],
  ///   startDate: DateTime.now().subtract(Duration(days: 7)),
  ///   endDate: DateTime.now(),
  /// );
  ///
  /// final stepsData = results[HealthDataType.steps];
  /// final heartRateData = results[HealthDataType.heartRate];
  /// ```
  static Future<Map<HealthDataType, HealthDataResult>> readMultipleHealthData({
    required HealthPlatform platform,
    required List<HealthDataType> dataTypes,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return HealthBridgePlatform.instance.readMultipleHealthData(
      platform: platform,
      dataTypes: dataTypes,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// 写入单条健康数据
  ///
  /// [platform] 目标健康平台
  /// [data] 要写入的健康数据
  ///
  /// 使用示例：
  /// ```dart
  /// final glucoseData = HealthData(
  ///   type: HealthDataType.glucose,
  ///   value: 5.6,
  ///   timestamp: DateTime.now().millisecondsSinceEpoch,
  ///   unit: 'mmol/L',
  ///   platform: platform,
  /// );
  ///
  /// final result = await HealthBridge.writeHealthData(
  ///   platform: platform,
  ///   data: glucoseData,
  /// );
  ///
  /// if (result.isSuccess) {
  ///   print('数据写入成功');
  /// }
  /// ```
  static Future<HealthDataResult> writeHealthData({
    required HealthPlatform platform,
    required HealthData data,
  }) {
    return HealthBridgePlatform.instance.writeHealthData(
      platform: platform,
      data: data,
    );
  }

  /// 批量写入健康数据
  ///
  /// [platform] 目标健康平台
  /// [dataList] 要写入的健康数据列表
  ///
  /// 使用示例：
  /// ```dart
  /// final dataList = [
  ///   HealthData(
  ///     type: HealthDataType.weight,
  ///     value: 70.5,
  ///     timestamp: DateTime.now().millisecondsSinceEpoch,
  ///     unit: 'kg',
  ///     platform: platform,
  ///   ),
  ///   HealthData(
  ///     type: HealthDataType.height,
  ///     value: 175,
  ///     timestamp: DateTime.now().millisecondsSinceEpoch,
  ///     unit: 'cm',
  ///     platform: platform,
  ///   ),
  /// ];
  ///
  /// final result = await HealthBridge.writeBatchHealthData(
  ///   platform: platform,
  ///   dataList: dataList,
  /// );
  /// ```
  static Future<HealthDataResult> writeBatchHealthData({
    required HealthPlatform platform,
    required List<HealthData> dataList,
  }) {
    return HealthBridgePlatform.instance.writeBatchHealthData(
      platform: platform,
      dataList: dataList,
    );
  }

  // ========== 华为云侧API ==========

  /// 设置华为云侧API凭证
  ///
  /// 在读取云侧数据前必须先调用此方法设置凭证
  ///
  /// [accessToken] OAuth授权获取的访问令牌
  /// [clientId] 华为AGC应用的Client ID
  ///
  /// 使用示例：
  /// ```dart
  /// // 1. 开发者自己完成OAuth授权，获取accessToken
  /// final oauthResult = await myOAuthFlow();
  ///
  /// // 2. 设置凭证
  /// await HealthBridge.setHuaweiCloudCredentials(
  ///   accessToken: oauthResult.accessToken!,
  ///   clientId: 'YOUR_CLIENT_ID',
  /// );
  ///
  /// // 3. 现在可以读取云侧数据了
  /// final result = await HealthBridge.readHealthData(
  ///   platform: HealthPlatform.huaweiCloud,
  ///   dataType: HealthDataType.steps,
  ///   startDate: DateTime.now().subtract(Duration(days: 7)),
  ///   endDate: DateTime.now(),
  /// );
  /// ```
  static Future<void> setHuaweiCloudCredentials({
    required String accessToken,
    required String clientId,
  }) async {
    final instance = HealthBridgePlatform.instance;
    if (instance is MethodChannelHealthBridge) {
      await instance.setHuaweiCloudCredentials(
        accessToken: accessToken,
        clientId: clientId,
      );
    } else {
      throw UnsupportedError('Cloud API is only supported with MethodChannelHealthBridge');
    }
  }

  /// 清除华为云侧API凭证
  ///
  /// 清除已设置的云侧API凭证
  static Future<void> clearCloudCredentials() async {
    final instance = HealthBridgePlatform.instance;
    if (instance is MethodChannelHealthBridge) {
      await instance.clearCloudCredentials();
    }
  }

  /// 读取华为云侧健康数据（支持指定查询类型）
  ///
  /// [dataType] 数据类型
  /// [startTime] 开始时间（毫秒时间戳）
  /// [endTime] 结束时间（毫秒时间戳）
  /// [queryType] 查询类型：'detail'原子读取，'daily'按天统计，默认'detail'
  ///
  /// 使用示例：
  /// ```dart
  /// // 原子查询（详细数据）
  /// final detailResult = await HealthBridge.readCloudHealthData(
  ///   dataType: HealthDataType.steps,
  ///   startTime: DateTime.now().subtract(Duration(days: 7)).millisecondsSinceEpoch,
  ///   endTime: DateTime.now().millisecondsSinceEpoch,
  ///   queryType: 'detail',
  /// );
  ///
  /// // 统计查询（按天汇总）
  /// final dailyResult = await HealthBridge.readCloudHealthData(
  ///   dataType: HealthDataType.steps,
  ///   startTime: DateTime.now().subtract(Duration(days: 7)).millisecondsSinceEpoch,
  ///   endTime: DateTime.now().millisecondsSinceEpoch,
  ///   queryType: 'daily',
  /// );
  /// ```
  static Future<HealthDataResult> readCloudHealthData({
    required HealthDataType dataType,
    required int startTime,
    required int endTime,
    String queryType = 'detail',
  }) async {
    final instance = HealthBridgePlatform.instance;
    if (instance is MethodChannelHealthBridge) {
      if (instance.cloudClient == null) {
        return HealthDataResult(
          status: HealthDataStatus.error,
          platform: HealthPlatform.huaweiCloud,
          message: 'Please call setHuaweiCloudCredentials first',
        );
      }

      return await instance.cloudClient!.readHealthData(
        dataType: dataType,
        startTime: startTime,
        endTime: endTime,
        queryType: queryType,
      );
    } else {
      throw UnsupportedError('Cloud API is only supported with MethodChannelHealthBridge');
    }
  }
}