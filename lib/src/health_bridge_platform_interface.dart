import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'health_bridge_method_channel.dart';
import 'models/health_data.dart';
import 'models/health_platform.dart';

/// HealthBridge平台接口的抽象基类
abstract class HealthBridgePlatform extends PlatformInterface {
  /// 构造函数
  HealthBridgePlatform() : super(token: _token);

  static final Object _token = Object();

  static HealthBridgePlatform _instance = MethodChannelHealthBridge();

  /// 当前平台实现的默认实例
  static HealthBridgePlatform get instance => _instance;

  /// 设置平台实现实例，主要用于测试
  static set instance(HealthBridgePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// 获取平台版本
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  /// 获取当前设备支持的健康平台列表
  Future<List<HealthPlatform>> getAvailableHealthPlatforms() {
    throw UnimplementedError('getAvailableHealthPlatforms() has not been implemented.');
  }

  /// 初始化指定的健康平台
  Future<HealthDataResult> initializeHealthPlatform(HealthPlatform platform) {
    throw UnimplementedError('initializeHealthPlatform() has not been implemented.');
  }

  /// 读取步数数据
  /// 
  /// [platform] 数据源健康平台
  /// [startDate] 开始日期，为null时读取今日数据
  /// [endDate] 结束日期，为null时读取startDate当日数据
  /// 
  /// 使用示例：
  /// - readStepCount(platform: platform) // 读取今日
  /// - readStepCount(platform: platform, startDate: date) // 读取指定日期
  /// - readStepCount(platform: platform, startDate: start, endDate: end) // 读取日期范围
  Future<HealthDataResult> readStepCount({
    required HealthPlatform platform,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    throw UnimplementedError('readStepCount() has not been implemented.');
  }

  /// 断开所有健康平台连接
  Future<void> disconnect() {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  // ========== 权限管理 ==========

  /// 检查指定数据类型的权限状态
  ///
  /// [platform] 健康平台
  /// [dataTypes] 要检查的数据类型列表
  /// [operation] 操作类型（读/写）
  ///
  /// 返回每个数据类型对应的权限状态
  Future<Map<HealthDataType, HealthPermissionStatus>> checkPermissions({
    required HealthPlatform platform,
    required List<HealthDataType> dataTypes,
    required HealthDataOperation operation,
  }) {
    throw UnimplementedError('checkPermissions() has not been implemented.');
  }

  /// 申请指定数据类型的权限
  ///
  /// [platform] 健康平台
  /// [dataTypes] 要申请的数据类型列表
  /// [operations] 操作类型列表（可以同时申请读写）
  /// [reason] 申请理由（可选，用于UI展示）
  ///
  /// 返回申请结果
  Future<HealthDataResult> requestPermissions({
    required HealthPlatform platform,
    required List<HealthDataType> dataTypes,
    required List<HealthDataOperation> operations,
    String? reason,
  }) {
    throw UnimplementedError('requestPermissions() has not been implemented.');
  }

  /// 按权限组申请权限（便利方法）
  ///
  /// [platform] 健康平台
  /// [group] 权限组
  /// [operations] 操作类型列表
  /// [reason] 申请理由
  Future<HealthDataResult> requestPermissionGroup({
    required HealthPlatform platform,
    required HealthPermissionGroup group,
    required List<HealthDataOperation> operations,
    String? reason,
  }) {
    return requestPermissions(
      platform: platform,
      dataTypes: group.dataTypes,
      operations: operations,
      reason: reason,
    );
  }

  /// 取消全部授权
  ///
  /// [platform] 健康平台
  ///
  /// 返回取消结果
  Future<HealthDataResult> revokeAllAuthorizations({
    required HealthPlatform platform,
  }) {
    throw UnimplementedError('revokeAllAuthorizations() has not been implemented.');
  }

  /// 取消部分授权（指定数据类型）
  ///
  /// [platform] 健康平台
  /// [dataTypes] 要取消授权的数据类型列表
  /// [operations] 操作类型列表
  ///
  /// 返回取消结果
  Future<HealthDataResult> revokeAuthorizations({
    required HealthPlatform platform,
    required List<HealthDataType> dataTypes,
    required List<HealthDataOperation> operations,
  }) {
    throw UnimplementedError('revokeAuthorizations() has not been implemented.');
  }

  // ========== 平台能力查询 ==========

  /// 获取指定平台支持的所有数据类型
  ///
  /// [platform] 健康平台
  /// [operation] 操作类型（可选，不指定则返回所有）
  ///
  /// 返回该平台支持的数据类型列表
  Future<List<HealthDataType>> getSupportedDataTypes({
    required HealthPlatform platform,
    HealthDataOperation? operation,
  }) async {
    // 默认实现：使用静态能力映射
    return platform.getSupportedDataTypes(operation: operation);
  }

  /// 检查指定平台是否支持某个数据类型
  ///
  /// [platform] 健康平台
  /// [dataType] 数据类型
  /// [operation] 操作类型
  ///
  /// 返回是否支持
  Future<bool> isDataTypeSupported({
    required HealthPlatform platform,
    required HealthDataType dataType,
    required HealthDataOperation operation,
  }) async {
    // 默认实现：使用静态能力映射
    return platform.supports(dataType, operation: operation);
  }

  /// 获取指定平台的详细能力信息
  ///
  /// [platform] 健康平台
  ///
  /// 返回能力列表（包含读写权限、特殊说明等）
  Future<List<PlatformCapability>> getPlatformCapabilities({
    required HealthPlatform platform,
  }) async {
    // 默认实现：返回静态能力映射
    return platform.capabilities;
  }

  // ========== 统一数据读写接口 ==========

  /// 读取健康数据（通用方法）
  ///
  /// [platform] 数据源健康平台
  /// [dataType] 数据类型
  /// [startDate] 开始日期
  /// [endDate] 结束日期
  /// [limit] 数据条数限制（可选）
  /// [queryType] 查询类型：'detail' 详情查询（默认），'statistics' 聚合查询
  Future<HealthDataResult> readHealthData({
    required HealthPlatform platform,
    required HealthDataType dataType,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    String? queryType,
  }) {
    throw UnimplementedError('readHealthData() has not been implemented.');
  }

  /// 批量读取多种健康数据
  ///
  /// [platform] 数据源健康平台
  /// [dataTypes] 数据类型列表
  /// [startDate] 开始日期
  /// [endDate] 结束日期
  Future<Map<HealthDataType, HealthDataResult>> readMultipleHealthData({
    required HealthPlatform platform,
    required List<HealthDataType> dataTypes,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final results = <HealthDataType, HealthDataResult>{};

    for (final dataType in dataTypes) {
      final result = await readHealthData(
        platform: platform,
        dataType: dataType,
        startDate: startDate,
        endDate: endDate,
      );
      results[dataType] = result;
    }

    return results;
  }

  /// 写入单条健康数据
  ///
  /// [platform] 目标健康平台
  /// [data] 要写入的健康数据
  Future<HealthDataResult> writeHealthData({
    required HealthPlatform platform,
    required HealthData data,
  }) {
    throw UnimplementedError('writeHealthData() has not been implemented.');
  }

  /// 批量写入健康数据
  ///
  /// [platform] 目标健康平台
  /// [dataList] 要写入的健康数据列表
  Future<HealthDataResult> writeBatchHealthData({
    required HealthPlatform platform,
    required List<HealthData> dataList,
  }) {
    throw UnimplementedError('writeBatchHealthData() has not been implemented.');
  }
}