import 'package:flutter/material.dart';
import 'package:health_bridge/health_bridge.dart';
import '../utils/constants.dart';
import 'health_data_detail_page.dart';

/// 数据读取页面
class DataReadingPage extends StatefulWidget {
  final HealthPlatform platform;

  const DataReadingPage({
    super.key,
    required this.platform,
  });

  @override
  State<DataReadingPage> createState() => _DataReadingPageState();
}

class _DataReadingPageState extends State<DataReadingPage> {
  // 数据缓存
  final Map<HealthDataType, List<HealthData>> _healthDataCache = {};

  // 权限状态缓存
  Map<HealthDataType, HealthPermissionStatus> _readPermissions = {};

  bool _isLoading = false;
  String? _currentLoadingType;
  
  // 查询类型：'detail' 详情查询，'statistics' 聚合查询
  String _queryType = 'detail';

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  /// 获取当前平台的测试数据类型列表
  List<HealthDataType> _getTestDataTypes() {
    switch (widget.platform) {
      case HealthPlatform.appleHealth:
        return appleHealthTestTypes;
      case HealthPlatform.huaweiHealth:
      case HealthPlatform.huaweiCloud:
        return huaweiTestTypes;
      default:
        return huaweiTestTypes;
    }
  }

  /// 检查权限状态
  Future<void> _checkPermissions() async {
    try {
      final permissions = await HealthBridge.checkPermissions(
        platform: widget.platform,
        dataTypes: _getTestDataTypes(),
        operation: HealthDataOperation.read,
      );

      if (!mounted) return;

      setState(() {
        _readPermissions = permissions;
      });
    } catch (e) {
      _showError('检查权限失败: $e');
    }
  }

  /// 读取健康数据
  Future<void> _readHealthData(HealthDataType dataType) async {
    setState(() {
      _isLoading = true;
      _currentLoadingType = dataType.displayName;
    });

    try {
      // 检查是否支持该数据类型
      final supported = await HealthBridge.isDataTypeSupported(
        platform: widget.platform,
        dataType: dataType,
        operation: HealthDataOperation.read,
      );

      if (!supported) {
        _showError('${dataType.displayName} 不支持读取');
        return;
      }

      // 确定时间范围
      final now = DateTime.now();
      DateTime startDate;
      
      // 根据查询类型和数据类型确定时间范围
      if (_queryType == 'statistics') {
        // 聚合查询：读取最近7天的数据
        startDate = now.subtract(const Duration(days: 7));
        startDate = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
      } else if (dataType == HealthDataType.height || dataType == HealthDataType.weight) {
        // 详情查询 + 身高体重：使用更长的时间范围（过去1年）
        // 因为这些数据通常不是每天都记录
        startDate = now.subtract(const Duration(days: 365));
      } else {
        // 详情查询 + 其他数据类型：读取今天的数据
        startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
      }

      print('📱 [Flutter] 开始读取数据');
      print('📱 [Flutter] 数据类型: ${dataType.displayName}');
      print('📱 [Flutter] 查询类型: $_queryType');
      print('📱 [Flutter] 时间范围: $startDate - $now');
      
      final result = await HealthBridge.readHealthData(
        platform: widget.platform,
        dataType: dataType,
        startDate: startDate,
        endDate: now,
        limit: 100,
        queryType: _queryType,
      );
      
      print('📱 [Flutter] 查询完成');
      print('📱 [Flutter] 状态: ${result.status}');
      print('📱 [Flutter] 数据条数: ${result.data.length}');

      if (!mounted) return;

      if (result.isSuccess) {
        print('📱 [Flutter] 数据缓存成功');
        
        setState(() {
          _healthDataCache[dataType] = result.data;
        });

        if (result.data.isEmpty) {
          print('⚠️ [Flutter] 无数据返回');
          // 根据数据类型和查询类型显示不同的提示
          if (dataType == HealthDataType.height || dataType == HealthDataType.weight) {
            _showInfo('${dataType.displayName}: 过去一年内暂无数据');
          } else {
            final timeRangeText = _queryType == 'statistics' ? '最近7天' : '今日';
            _showInfo('${dataType.displayName}: ${timeRangeText}暂无数据');
          }
        } else {
          final queryTypeText = _queryType == 'detail' ? '详情' : '聚合';
          print('✅ [Flutter] 获取到 ${result.data.length} 条${queryTypeText}数据');
          
          // 打印前3条数据示例
          for (var i = 0; i < (result.data.length > 3 ? 3 : result.data.length); i++) {
            final data = result.data[i];
            print('   数据 ${i + 1}: 值=${data.value}, 时间=${data.timestamp}, 来源=${data.source}');
            
            // 对于血糖数据，打印完整的 metadata
            if (dataType == HealthDataType.glucose && data.metadata.isNotEmpty) {
              print('   📋 Metadata详情:');
              data.metadata.forEach((key, value) {
                print('      - $key: $value (${value.runtimeType})');
              });
            }
          }
          
          _showSuccess('${dataType.displayName}: 读取到 ${result.data.length} 条${queryTypeText}数据');
          
          // 自动跳转到详情页
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => HealthDataDetailPage(
                dataType: dataType,
                dataList: result.data,
                platform: widget.platform,
                isGroupedByDay: _queryType == 'statistics', // 聚合查询时按天分组
              ),
            ),
          );
        }
      } else {
        print('❌ [Flutter] 读取失败: ${result.message}');
        _showError('${dataType.displayName} 读取失败: ${result.message}');
      }
    } catch (e) {
      _showError('读取异常: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _currentLoadingType = null;
      });
    }
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

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.blue),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.platform.displayName} 数据读取'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkPermissions,
            tooltip: '刷新权限状态',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 说明卡片
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          '数据读取说明',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• 选择查询模式：详情查询或聚合查询\n'
                      '• 详情查询：返回原始记录，按时间顺序显示\n'
                      '• 聚合查询：返回原始记录，按天分组显示\n'
                      '• 聚合模式会显示每天的统计（平均值、最大最小值等）\n'
                      '• 读取成功后自动跳转到详情页',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 查询类型选择
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '查询模式',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'detail',
                          label: Text('详情查询'),
                          icon: Icon(Icons.list),
                        ),
                        ButtonSegment(
                          value: 'statistics',
                          label: Text('聚合查询'),
                          icon: Icon(Icons.bar_chart),
                        ),
                      ],
                      selected: {_queryType},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _queryType = newSelection.first;
                          // 清除缓存，因为查询类型改变了
                          _healthDataCache.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _queryType == 'detail'
                          ? '📝 详情查询：返回所有原始记录，不分组展示'
                          : '📊 聚合查询：返回所有原始记录，按天分组展示',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 数据类型列表
            ..._getTestDataTypes().map((dataType) {
              final dataList = _healthDataCache[dataType];
              final hasData = dataList != null && dataList.isNotEmpty;
              final permission = _readPermissions[dataType];
              final isLoading = _isLoading && _currentLoadingType == dataType.displayName;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: hasData ? 3 : 1,
                color: hasData ? Colors.green.shade50 : null,
                child: InkWell(
                  onTap: hasData
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => HealthDataDetailPage(
                                dataType: dataType,
                                dataList: dataList,
                                platform: widget.platform,
                                isGroupedByDay: _queryType == 'statistics', // 聚合查询时按天分组
                              ),
                            ),
                          );
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 标题行
                        Row(
                          children: [
                            Icon(
                              _getDataTypeIcon(dataType),
                              size: 32,
                              color: hasData
                                  ? Colors.green.shade700
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dataType.displayName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: hasData ? Colors.green.shade900 : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        _getPermissionIcon(permission),
                                        size: 14,
                                        color: _getPermissionColor(permission),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        permission?.displayName ?? '未检查',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _getPermissionColor(permission),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 数据信息
                        if (hasData) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.data_array,
                                  size: 20,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '已读取 ${dataList.length} 条数据',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green.shade900,
                                    ),
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.green.shade700,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // 读取按钮
                        ElevatedButton.icon(
                          onPressed: isLoading ? null : () => _readHealthData(dataType),
                          icon: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.download),
                          label: Text(isLoading ? '读取中...' : '读取数据'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(40),
                            backgroundColor: hasData ? Colors.green : null,
                            foregroundColor: hasData ? Colors.white : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 获取数据类型图标
  IconData _getDataTypeIcon(HealthDataType dataType) {
    switch (dataType) {
      case HealthDataType.steps:
        return Icons.directions_walk;
      case HealthDataType.glucose:
        return Icons.water_drop;
      case HealthDataType.bloodPressure:
        return Icons.favorite;
      case HealthDataType.height:
        return Icons.height;
      case HealthDataType.weight:
        return Icons.monitor_weight;
      default:
        return Icons.health_and_safety;
    }
  }
}
