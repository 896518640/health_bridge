import 'package:flutter/material.dart';
import 'dart:async';

import 'package:health_bridge/health_bridge.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Bridge 完整测试',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HealthBridgeTestDemo(),
    );
  }
}

class HealthBridgeTestDemo extends StatefulWidget {
  const HealthBridgeTestDemo({super.key});

  @override
  State<HealthBridgeTestDemo> createState() => _HealthBridgeTestDemoState();
}

class _HealthBridgeTestDemoState extends State<HealthBridgeTestDemo> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _platformVersion = '未知';
  List<HealthPlatform> _availablePlatforms = [];
  HealthPlatform? _selectedPlatform;
  List<PlatformCapability> _platformCapabilities = [];

  // 权限状态
  Map<HealthDataType, HealthPermissionStatus> _readPermissions = {};
  Map<HealthDataType, HealthPermissionStatus> _writePermissions = {};

  // 权限选择状态
  Set<HealthDataType> _selectedReadTypes = {};
  Set<HealthDataType> _selectedWriteTypes = {};

  // 数据读取结果
  final Map<HealthDataType, List<HealthData>> _healthDataCache = {};

  // getSupportedDataTypes 演示数据
  List<HealthDataType> _allSupportedDataTypes = [];
  List<HealthDataType> _readableSupportedTypes = [];
  List<HealthDataType> _writableSupportedTypes = [];

  bool _isLoading = false;

  // 滚动控制器，用于保持滚动位置
  final ScrollController _readDataScrollController = ScrollController();
  final ScrollController _writeDataScrollController = ScrollController();

  // iOS支持的所有数据类型
  final List<HealthDataType> _allSupportedTypes = [
    HealthDataType.steps,
    HealthDataType.distance,
    HealthDataType.activeCalories,
    HealthDataType.glucose,
    HealthDataType.heartRate,
    HealthDataType.bloodPressureSystolic,
    HealthDataType.bloodPressureDiastolic,
    HealthDataType.weight,
    HealthDataType.height,
    HealthDataType.bodyFat,
    HealthDataType.bmi,
    HealthDataType.oxygenSaturation,
    HealthDataType.bodyTemperature,
    HealthDataType.respiratoryRate,
    HealthDataType.water,
    HealthDataType.sleepDuration,
    HealthDataType.sleepDeep,
    HealthDataType.sleepLight,
    HealthDataType.sleepREM,
    HealthDataType.workout,
  ];

  // 可写入的数据类型(华为Health Kit支持写入)
  final List<HealthDataType> _writableTypes = [
    HealthDataType.steps,           // 步数 - 华为支持写入
    HealthDataType.glucose,         // 血糖 - 华为支持写入
    HealthDataType.bloodPressureSystolic,   // 收缩压 - 华为支持写入
    HealthDataType.bloodPressureDiastolic,  // 舒张压 - 华为支持写入
    HealthDataType.weight,          // 体重 - 华为支持写入
    HealthDataType.height,          // 身高 - 华为支持写入
    HealthDataType.bodyFat,         // 体脂率 - 华为支持写入
    HealthDataType.oxygenSaturation,  // iOS支持
    HealthDataType.bodyTemperature,   // iOS支持
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initPlatformState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _readDataScrollController.dispose();
    _writeDataScrollController.dispose();
    super.dispose();
  }

  /// 初始化平台
  Future<void> _initPlatformState() async {
    setState(() => _isLoading = true);

    try {
      final version = await HealthBridge.getPlatformVersion() ?? '未知';
      final platforms = await HealthBridge.getAvailableHealthPlatforms();

      if (!mounted) return;

      setState(() {
        _platformVersion = version;
        _availablePlatforms = platforms;
        if (platforms.isNotEmpty) {
          _selectedPlatform = platforms.first;
          _loadPlatformCapabilities(platforms.first);
        }
      });
    } catch (e) {
      _showError('初始化失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 加载平台能力
  Future<void> _loadPlatformCapabilities(HealthPlatform platform) async {
    try {
      final capabilities = await HealthBridge.getPlatformCapabilities(
        platform: platform,
      );

      if (!mounted) return;

      setState(() {
        _platformCapabilities = capabilities;
      });

      // 同时加载 getSupportedDataTypes 的数据
      await _loadSupportedDataTypes(platform);
    } catch (e) {
      _showError('加载平台能力失败: $e');
    }
  }

  /// 加载支持的数据类型（演示 getSupportedDataTypes）
  Future<void> _loadSupportedDataTypes(HealthPlatform platform) async {
    try {
      // 获取所有支持的数据类型
      final allTypes = await HealthBridge.getSupportedDataTypes(
        platform: platform,
      );

      // 获取可读的数据类型
      final readableTypes = await HealthBridge.getSupportedDataTypes(
        platform: platform,
        operation: HealthDataOperation.read,
      );

      // 获取可写的数据类型
      final writableTypes = await HealthBridge.getSupportedDataTypes(
        platform: platform,
        operation: HealthDataOperation.write,
      );

      if (!mounted) return;

      setState(() {
        _allSupportedDataTypes = allTypes;
        _readableSupportedTypes = readableTypes;
        _writableSupportedTypes = writableTypes;
      });
    } catch (e) {
      _showError('加载支持的数据类型失败: $e');
    }
  }

  /// 检查所有数据类型的读权限
  Future<void> _checkAllReadPermissions() async {
    if (_selectedPlatform == null) return;

    setState(() => _isLoading = true);

    try {
      final permissions = await HealthBridge.checkPermissions(
        platform: _selectedPlatform!,
        dataTypes: _allSupportedTypes,
        operation: HealthDataOperation.read,
      );

      if (!mounted) return;

      setState(() {
        _readPermissions = permissions;
      });

      _showSuccess('已检查 ${permissions.length} 种数据类型的读权限');
    } catch (e) {
      _showError('检查读权限失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 检查所有可写数据类型的写权限
  Future<void> _checkAllWritePermissions() async {
    if (_selectedPlatform == null) return;

    setState(() => _isLoading = true);

    try {
      final permissions = await HealthBridge.checkPermissions(
        platform: _selectedPlatform!,
        dataTypes: _writableTypes,
        operation: HealthDataOperation.write,
      );

      if (!mounted) return;

      setState(() {
        _writePermissions = permissions;
      });

      _showSuccess('已检查 ${permissions.length} 种数据类型的写权限');
    } catch (e) {
      _showError('检查写权限失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 申请选中的读权限
  Future<void> _requestSelectedReadPermissions() async {
    if (_selectedPlatform == null || _selectedReadTypes.isEmpty) {
      _showError('请先选择要申请的数据类型');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await HealthBridge.requestPermissions(
        platform: _selectedPlatform!,
        dataTypes: _selectedReadTypes.toList(),
        operations: [HealthDataOperation.read],
        reason: '读取选中的健康数据类型',
      );

      if (!mounted) return;

      if (result.isSuccess) {
        _showSuccess('已申请 ${_selectedReadTypes.length} 种数据类型的读权限');
        await _checkAllReadPermissions();
      } else {
        _showError('申请失败: ${result.message}');
      }
    } catch (e) {
      _showError('申请权限异常: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 申请选中的写权限
  Future<void> _requestSelectedWritePermissions() async {
    if (_selectedPlatform == null || _selectedWriteTypes.isEmpty) {
      _showError('请先选择要申请的数据类型');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await HealthBridge.requestPermissions(
        platform: _selectedPlatform!,
        dataTypes: _selectedWriteTypes.toList(),
        operations: [HealthDataOperation.write],
        reason: '写入选中的健康数据类型',
      );

      if (!mounted) return;

      if (result.isSuccess) {
        _showSuccess('已申请 ${_selectedWriteTypes.length} 种数据类型的写权限');
        await _checkAllWritePermissions();
      } else {
        _showError('申请失败: ${result.message}');
      }
    } catch (e) {
      _showError('申请权限异常: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 读取单个数据类型
  Future<void> _readHealthData(HealthDataType dataType) async {
    if (_selectedPlatform == null) return;

    setState(() => _isLoading = true);

    try {
      final supported = await HealthBridge.isDataTypeSupported(
        platform: _selectedPlatform!,
        dataType: dataType,
        operation: HealthDataOperation.read,
      );

      if (!supported) {
        _showError('${dataType.displayName} 不支持读取');
        return;
      }

      // 华为Health Kit默认只能查询授权后的数据
      // 不申请历史数据权限，只查询今天的数据（参考官方demo）
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);

      final result = await HealthBridge.readHealthData(
        platform: _selectedPlatform!,
        dataType: dataType,
        startDate: todayStart,  // 今天00:00:00
        endDate: now,  // 现在
        limit: 100,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        setState(() {
          _healthDataCache[dataType] = result.data;
        });

        if (result.data.isEmpty) {
          _showInfo('${dataType.displayName}: 无数据');
        } else {
          _showSuccess('${dataType.displayName}: 读取到 ${result.data.length} 条数据');
          // 显示数据详情
          _showDataDetailDialog(dataType, result.data);
        }
      } else {
        _showError('${dataType.displayName} 读取失败: ${result.message}');
      }
    } catch (e) {
      _showError('读取异常: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 显示数据详情对话框
  void _showDataDetailDialog(HealthDataType dataType, List<HealthData> dataList) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dataType.displayName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '共 ${dataList.length} 条数据',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              // 数据列表
              Expanded(
                child: ListView.builder(
                  itemCount: dataList.length,
                  itemBuilder: (context, index) {
                    final data = dataList[index];
                    final time = DateTime.fromMillisecondsSinceEpoch(data.timestamp);
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text('${index + 1}'),
                      ),
                      title: Text(
                        '${data.value} ${data.unit}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '时间: ${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
                            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                          ),
                          if (data.source != null)
                            Text('来源: ${data.source}'),
                        ],
                      ),
                      dense: true,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 写入健康数据（示例值）
  Future<void> _writeHealthData(HealthDataType dataType) async {
    if (_selectedPlatform == null) return;

    final supported = await HealthBridge.isDataTypeSupported(
      platform: _selectedPlatform!,
      dataType: dataType,
      operation: HealthDataOperation.write,
    );

    if (!supported) {
      _showError('${dataType.displayName} 不支持写入');
      return;
    }

    final sampleData = _getSampleDataForType(dataType);
    if (sampleData == null) {
      _showError('无法生成示例数据');
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: '写入${dataType.displayName}',
      message: '将写入示例数据：${sampleData['value']} ${sampleData['unit']}',
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      final healthData = HealthData(
        type: dataType,
        value: sampleData['value'] as double,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        unit: sampleData['unit'] as String,
        platform: _selectedPlatform!,
      );

      final result = await HealthBridge.writeHealthData(
        platform: _selectedPlatform!,
        data: healthData,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        _showSuccess('${dataType.displayName} 写入成功: ${sampleData['value']} ${sampleData['unit']}');
      } else {
        _showError('写入失败: ${result.message}');
      }
    } catch (e) {
      _showError('写入异常: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 获取数据类型的示例数据
  Map<String, dynamic>? _getSampleDataForType(HealthDataType dataType) {
    switch (dataType) {
      case HealthDataType.steps:
        return {'value': 1000.0, 'unit': 'steps'};
      case HealthDataType.glucose:
        return {'value': 5.6, 'unit': 'mmol/L'};
      case HealthDataType.bloodPressureSystolic:
        return {'value': 120.0, 'unit': 'mmHg'};
      case HealthDataType.bloodPressureDiastolic:
        return {'value': 80.0, 'unit': 'mmHg'};
      case HealthDataType.weight:
        return {'value': 70.0, 'unit': 'kg'};
      case HealthDataType.height:
        return {'value': 1.75, 'unit': 'm'};
      case HealthDataType.bodyFat:
        return {'value': 18.5, 'unit': '%'};
      case HealthDataType.oxygenSaturation:
        return {'value': 98.0, 'unit': '%'};
      case HealthDataType.bodyTemperature:
        return {'value': 36.5, 'unit': '°C'};
      default:
        return null;
    }
  }

  /// 显示确认对话框
  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('确定'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// 显示成功消息
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 显示信息
  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 显示错误消息
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 获取权限状态图标
  IconData _getPermissionIcon(HealthPermissionStatus? status) {
    if (status == null) return Icons.help_outline;
    switch (status) {
      case HealthPermissionStatus.granted:
        return Icons.check_circle;
      case HealthPermissionStatus.denied:
        return Icons.cancel;
      case HealthPermissionStatus.notDetermined:
        return Icons.help_outline;
      case HealthPermissionStatus.restricted:
        return Icons.lock;
    }
  }

  /// 获取权限状态颜色
  Color _getPermissionColor(HealthPermissionStatus? status) {
    if (status == null) return Colors.grey;
    switch (status) {
      case HealthPermissionStatus.granted:
        return Colors.green;
      case HealthPermissionStatus.denied:
        return Colors.red;
      case HealthPermissionStatus.notDetermined:
        return Colors.orange;
      case HealthPermissionStatus.restricted:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Bridge 完整测试'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: '平台信息'),
            Tab(icon: Icon(Icons.security), text: '权限管理'),
            Tab(icon: Icon(Icons.download), text: '数据读取'),
            Tab(icon: Icon(Icons.upload), text: '数据写入'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPlatformTab(),
                _buildPermissionsTab(),
                _buildReadDataTab(),
                _buildWriteDataTab(),
              ],
            ),
    );
  }

  /// 平台信息标签页
  Widget _buildPlatformTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '平台基本信息',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildInfoRow('系统版本', _platformVersion),
                  _buildInfoRow(
                    '可用平台',
                    _availablePlatforms.map((p) => p.displayName).join(', '),
                  ),
                  if (_selectedPlatform != null)
                    _buildInfoRow('当前平台', _selectedPlatform!.displayName),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '平台能力',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    '支持的数据类型',
                    '${_platformCapabilities.length} 种',
                  ),
                  _buildInfoRow(
                    '可读取',
                    '${_platformCapabilities.where((c) => c.canRead).length} 种',
                  ),
                  _buildInfoRow(
                    '可写入',
                    '${_platformCapabilities.where((c) => c.canWrite).length} 种',
                  ),
                  const SizedBox(height: 16),
                  const Text('数据类型详情：', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _platformCapabilities.map((cap) {
                      String icon;
                      if (cap.canRead && cap.canWrite) {
                        icon = '✅';
                      } else if (cap.canRead) {
                        icon = '📖';
                      } else if (cap.canWrite) {
                        icon = '✏️';
                      } else {
                        icon = '❌';
                      }
                      return Chip(
                        avatar: Text(icon, style: const TextStyle(fontSize: 16)),
                        label: Text(cap.dataType.displayName),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // getSupportedDataTypes 方法演示
          if (_allSupportedDataTypes.isNotEmpty)
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.code, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'getSupportedDataTypes() 演示',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              const Text(
                                '此方法用于动态获取平台支持的数据类型',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '使用场景：\n'
                            '• 根据平台能力动态显示UI\n'
                            '• 跨平台兼容性检查\n'
                            '• 功能降级处理',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 方法调用示例1
                    _buildMethodCallExample(
                      methodCall: 'getSupportedDataTypes(platform: ${'platform'})',
                      description: '获取所有支持的数据类型',
                      resultCount: _allSupportedDataTypes.length,
                      resultTypes: _allSupportedDataTypes.take(5).map((t) => t.displayName).toList(),
                    ),
                    const SizedBox(height: 12),

                    // 方法调用示例2
                    _buildMethodCallExample(
                      methodCall: 'getSupportedDataTypes(platform: platform, operation: read)',
                      description: '获取支持读取的数据类型',
                      resultCount: _readableSupportedTypes.length,
                      resultTypes: _readableSupportedTypes.take(5).map((t) => t.displayName).toList(),
                    ),
                    const SizedBox(height: 12),

                    // 方法调用示例3
                    _buildMethodCallExample(
                      methodCall: 'getSupportedDataTypes(platform: platform, operation: write)',
                      description: '获取支持写入的数据类型',
                      resultCount: _writableSupportedTypes.length,
                      resultTypes: _writableSupportedTypes.take(5).map((t) => t.displayName).toList(),
                    ),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '这些数据在应用启动时自动调用 getSupportedDataTypes() 获取',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建方法调用示例卡片
  Widget _buildMethodCallExample({
    required String methodCall,
    required String description,
    required int resultCount,
    required List<String> resultTypes,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 方法调用
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              methodCall,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: Colors.purple.shade700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 描述
          Text(
            description,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // 结果
          Row(
            children: [
              Icon(Icons.arrow_forward, size: 14, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Text(
                '返回 $resultCount 种: ',
                style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
              ),
              Expanded(
                child: Text(
                  resultTypes.join(', ') + (resultCount > 5 ? '...' : ''),
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 权限管理标签页
  Widget _buildPermissionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 读权限
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '读权限 (${_allSupportedTypes.length}种)',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        onPressed: _checkAllReadPermissions,
                        icon: const Icon(Icons.refresh),
                        tooltip: '刷新',
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'iOS限制：读权限状态总是显示"未确定"，这是隐私保护设计',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 全选/取消全选
                  Row(
                    children: [
                      Expanded(
                        child: Text('已选择 ${_selectedReadTypes.length} 种'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedReadTypes.clear();
                            _selectedReadTypes.addAll(_allSupportedTypes);
                          });
                        },
                        child: const Text('全选'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedReadTypes.clear());
                        },
                        child: const Text('取消'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 数据类型选择列表
                  ..._allSupportedTypes.map((type) {
                    final status = _readPermissions[type];
                    final isSelected = _selectedReadTypes.contains(type);
                    return CheckboxListTile(
                      dense: true,
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedReadTypes.add(type);
                          } else {
                            _selectedReadTypes.remove(type);
                          }
                        });
                      },
                      secondary: Icon(
                        _getPermissionIcon(status),
                        color: _getPermissionColor(status),
                        size: 20,
                      ),
                      title: Text(
                        type.displayName,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        status?.displayName ?? '未检查',
                        style: TextStyle(
                          color: _getPermissionColor(status),
                          fontSize: 11,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _requestSelectedReadPermissions,
                    icon: const Icon(Icons.lock_open),
                    label: Text('申请选中的读权限 (${_selectedReadTypes.length})'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 写权限
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '写权限 (${_writableTypes.length}种)',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        onPressed: _checkAllWritePermissions,
                        icon: const Icon(Icons.refresh),
                        tooltip: '刷新',
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '写权限可以准确检查状态',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 全选/取消全选
                  Row(
                    children: [
                      Expanded(
                        child: Text('已选择 ${_selectedWriteTypes.length} 种'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedWriteTypes.clear();
                            _selectedWriteTypes.addAll(_writableTypes);
                          });
                        },
                        child: const Text('全选'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedWriteTypes.clear());
                        },
                        child: const Text('取消'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 数据类型选择列表
                  ..._writableTypes.map((type) {
                    final status = _writePermissions[type];
                    final isSelected = _selectedWriteTypes.contains(type);
                    return CheckboxListTile(
                      dense: true,
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedWriteTypes.add(type);
                          } else {
                            _selectedWriteTypes.remove(type);
                          }
                        });
                      },
                      secondary: Icon(
                        _getPermissionIcon(status),
                        color: _getPermissionColor(status),
                        size: 20,
                      ),
                      title: Text(
                        type.displayName,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        status?.displayName ?? '未检查',
                        style: TextStyle(
                          color: _getPermissionColor(status),
                          fontSize: 11,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _requestSelectedWritePermissions,
                    icon: const Icon(Icons.lock_open),
                    label: Text('申请选中的写权限 (${_selectedWriteTypes.length})'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 数据读取标签页
  Widget _buildReadDataTab() {
    // 使用平台实际支持的数据类型，而不是硬编码的_allSupportedTypes
    final supportedTypes = _readableSupportedTypes.isNotEmpty
        ? _readableSupportedTypes
        : _allSupportedTypes;

    return SingleChildScrollView(
      controller: _readDataScrollController,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '健康数据读取',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '显示当前平台支持的 ${supportedTypes.length} 种数据类型',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '点击"读取"按钮后会显示今天的数据（最多100条）',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...supportedTypes.map((type) {
                    final dataList = _healthDataCache[type];
                    final hasData = dataList != null && dataList.isNotEmpty;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: hasData ? 2 : 1,
                      color: hasData ? Colors.blue.shade50 : null,
                      child: ListTile(
                        leading: Icon(
                          hasData ? Icons.check_circle : Icons.circle_outlined,
                          color: hasData ? Colors.green : Colors.grey,
                        ),
                        title: Text(
                          type.displayName,
                          style: TextStyle(
                            fontWeight: hasData ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: hasData
                            ? Text(
                                '${dataList.length}条数据 - 点击查看详情',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 12,
                                ),
                              )
                            : Text(
                                type.unit,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                        trailing: IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () => _readHealthData(type),
                          tooltip: '读取${type.displayName}',
                        ),
                        onTap: hasData
                            ? () => _showDataDetailDialog(type, dataList)
                            : null,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 数据写入标签页
  Widget _buildWriteDataTab() {
    return SingleChildScrollView(
      controller: _writeDataScrollController,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '健康数据写入',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '写入前请先在权限管理中申请对应的写权限',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._writableTypes.map((type) {
                    final sampleData = _getSampleDataForType(type);
                    final status = _writePermissions[type];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          _getPermissionIcon(status),
                          color: _getPermissionColor(status),
                        ),
                        title: Text(type.displayName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (sampleData != null)
                              Text(
                                '示例值: ${sampleData['value']} ${sampleData['unit']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            Text(
                              '权限: ${status?.displayName ?? "未检查"}',
                              style: TextStyle(
                                fontSize: 11,
                                color: _getPermissionColor(status),
                              ),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: () => _writeHealthData(type),
                          icon: const Icon(Icons.upload, size: 16),
                          label: const Text('写入'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 信息行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
