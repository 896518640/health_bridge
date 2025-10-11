import 'package:flutter/material.dart';
import 'package:health_bridge/health_bridge.dart';
import '../utils/constants.dart';

/// 权限管理页面
class PermissionManagementPage extends StatefulWidget {
  final HealthPlatform platform;

  const PermissionManagementPage({
    super.key,
    required this.platform,
  });

  @override
  State<PermissionManagementPage> createState() => _PermissionManagementPageState();
}

class _PermissionManagementPageState extends State<PermissionManagementPage> {
  // 权限状态缓存
  Map<HealthDataType, HealthPermissionStatus> _readPermissions = {};
  Map<HealthDataType, HealthPermissionStatus> _writePermissions = {};

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAllPermissions();
  }

  /// 检查所有权限
  Future<void> _checkAllPermissions() async {
    setState(() => _isLoading = true);

    try {
      // 检查读权限
      final readPerms = await HealthBridge.checkPermissions(
        platform: widget.platform,
        dataTypes: huaweiTestTypes,
        operation: HealthDataOperation.read,
      );

      // 检查写权限
      final writePerms = await HealthBridge.checkPermissions(
        platform: widget.platform,
        dataTypes: huaweiTestTypes,
        operation: HealthDataOperation.write,
      );

      if (!mounted) return;

      setState(() {
        _readPermissions = readPerms;
        _writePermissions = writePerms;
      });
    } catch (e) {
      _showError('检查权限失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 申请单个数据类型的读权限
  Future<void> _requestReadPermission(HealthDataType dataType) async {
    setState(() => _isLoading = true);

    try {
      final result = await HealthBridge.requestPermissions(
        platform: widget.platform,
        dataTypes: [dataType],
        operations: [HealthDataOperation.read],
        reason: '读取 ${dataType.displayName} 数据',
      );

      if (!mounted) return;

      if (result.isSuccess) {
        _showSuccess('已申请 ${dataType.displayName} 读权限');
        await _checkAllPermissions();
      } else {
        _showError('申请失败: ${result.message}');
      }
    } catch (e) {
      _showError('申请权限异常: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 申请单个数据类型的写权限
  Future<void> _requestWritePermission(HealthDataType dataType) async {
    setState(() => _isLoading = true);

    try {
      final result = await HealthBridge.requestPermissions(
        platform: widget.platform,
        dataTypes: [dataType],
        operations: [HealthDataOperation.write],
        reason: '写入 ${dataType.displayName} 数据',
      );

      if (!mounted) return;

      if (result.isSuccess) {
        _showSuccess('已申请 ${dataType.displayName} 写权限');
        await _checkAllPermissions();
      } else {
        _showError('申请失败: ${result.message}');
      }
    } catch (e) {
      _showError('申请权限异常: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 取消全部授权
  Future<void> _revokeAllAuthorizations() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消全部授权'),
        content: Text(
          '确定要取消 ${widget.platform.displayName} 的所有授权吗？\n\n'
          '这将取消所有数据类型的读写权限。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final result = await HealthBridge.revokeAllAuthorizations(
        platform: widget.platform,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        _showSuccess('已成功取消全部授权');
        await _checkAllPermissions();
      } else {
        _showError('取消授权失败: ${result.message}');
      }
    } catch (e) {
      _showError('取消授权异常: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 取消单个数据类型的授权
  Future<void> _revokeDataTypeAuthorization(HealthDataType dataType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消授权'),
        content: Text(
          '确定要取消 ${dataType.displayName} 的所有授权吗？\n\n'
          '这将取消该数据类型的读写权限。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final result = await HealthBridge.revokeAuthorizations(
        platform: widget.platform,
        dataTypes: [dataType],
        operations: [HealthDataOperation.read, HealthDataOperation.write],
      );

      if (!mounted) return;

      if (result.isSuccess) {
        _showSuccess('已成功取消 ${dataType.displayName} 的授权');
        await _checkAllPermissions();
      } else {
        _showError('取消授权失败: ${result.message}');
      }
    } catch (e) {
      _showError('取消授权异常: $e');
    } finally {
      setState(() => _isLoading = false);
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
        title: Text('${widget.platform.displayName} 权限管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkAllPermissions,
            tooltip: '刷新权限状态',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 取消全部授权按钮
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Text(
                                '取消全部授权',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '点击下方按钮可取消所有数据类型的读写权限',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _revokeAllAuthorizations,
                            icon: const Icon(Icons.block),
                            label: const Text('取消全部授权'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(40),
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 数据类型权限列表
                  ...huaweiTestTypes.map((dataType) {
                    final readStatus = _readPermissions[dataType];
                    final writeStatus = _writePermissions[dataType];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 数据类型标题
                            Row(
                              children: [
                                Icon(
                                  _getDataTypeIcon(dataType),
                                  size: 32,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dataType.displayName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        dataType.unit,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),

                            // 读权限
                            _buildPermissionRow(
                              label: '读权限',
                              status: readStatus,
                              onRequest: () => _requestReadPermission(dataType),
                            ),
                            const SizedBox(height: 12),

                            // 写权限
                            _buildPermissionRow(
                              label: '写权限',
                              status: writeStatus,
                              onRequest: () => _requestWritePermission(dataType),
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),

                            // 取消授权按钮
                            OutlinedButton.icon(
                              onPressed: () => _revokeDataTypeAuthorization(dataType),
                              icon: const Icon(Icons.block, size: 16),
                              label: const Text('取消该数据类型的授权'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: BorderSide(color: Colors.red.shade300),
                                minimumSize: const Size.fromHeight(36),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  /// 构建权限行
  Widget _buildPermissionRow({
    required String label,
    required HealthPermissionStatus? status,
    required VoidCallback onRequest,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          _getPermissionIcon(status),
          color: _getPermissionColor(status),
          size: 24,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            status?.displayName ?? '未检查',
            style: TextStyle(
              color: _getPermissionColor(status),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: onRequest,
          icon: const Icon(Icons.lock_open, size: 16),
          label: const Text('申请'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
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
      default:
        return Icons.health_and_safety;
    }
  }
}
