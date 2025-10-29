import 'package:flutter/cupertino.dart';
import 'package:health_bridge/health_bridge.dart';
import 'health_data_detail_page.dart';

/// 平台权限管理页面（iOS风格）
class PlatformPermissionPage extends StatefulWidget {
  final HealthPlatform platform;

  const PlatformPermissionPage({
    super.key,
    required this.platform,
  });

  @override
  State<PlatformPermissionPage> createState() => _PlatformPermissionPageState();
}

class _PlatformPermissionPageState extends State<PlatformPermissionPage> {
  bool _isLoading = false;
  bool _isInitialized = false;
  Map<HealthDataType, HealthPermissionStatus> _permissionStatus = {};

  // 根据平台获取支持的数据类型
  List<HealthDataType> get _supportedDataTypes {
    switch (widget.platform) {
      case HealthPlatform.appleHealth:
        return [
          HealthDataType.steps,
          HealthDataType.glucose,
          HealthDataType.bloodPressure,
          HealthDataType.height,
          HealthDataType.weight,
        ];
      case HealthPlatform.huaweiHealth:
      case HealthPlatform.huaweiCloud:
        return [
          HealthDataType.steps,
          HealthDataType.glucose,
          HealthDataType.bloodPressure,
        ];
      default:
        return [];
    }
  }

  @override
  void initState() {
    super.initState();
    // 进入页面时只检查权限状态，不自动授权
    _checkAllPermissions();
  }

  /// 一键授权所有权限
  Future<void> _requestAllPermissions() async {
    setState(() => _isLoading = true);

    try {
      final dataTypes = _supportedDataTypes;
      final operations = [HealthDataOperation.read];

      print('>>> 一键授权所有权限: ${widget.platform.displayName}');
      print('>>> 数据类型: ${dataTypes.map((t) => t.displayName).join(", ")}');

      final result = await HealthBridge.initializeHealthPlatform(
        widget.platform,
        dataTypes: dataTypes,
        operations: operations,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        setState(() => _isInitialized = true);
        print('>>> 授权成功，开始验证数据访问...');
        
        // 授权成功后，延迟一下让系统完成授权
        await Future.delayed(const Duration(milliseconds: 500));
        
        // 重新检查权限状态
        await _checkAllPermissions();
        
        // 强制读取最近7天的数据来验证授权是否真正生效
        await _verifyAuthorizationByReadingData(dataTypes);
      } else {
        _showError('授权失败', result.message ?? '未知错误');
      }
    } catch (e) {
      print('!!! 授权异常: $e');
      _showError('授权异常', e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 检查所有权限状态
  Future<void> _checkAllPermissions() async {
    try {
      final permissions = await HealthBridge.checkPermissions(
        platform: widget.platform,
        dataTypes: _supportedDataTypes,
        operation: HealthDataOperation.read,
      );

      if (!mounted) return;

      setState(() {
        _permissionStatus = permissions;
        _isInitialized = true;  // ✅ 标记为已初始化
      });

      print('>>> 权限状态: ${permissions.map((k, v) => MapEntry(k.key, v.name))}');
    } catch (e) {
      print('!!! 检查权限失败: $e');
      // 即使失败也标记为已初始化，避免一直显示加载
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    }
  }

  /// 请求单个权限（Apple Health需要重新初始化追加权限）
  Future<void> _requestPermission(HealthDataType dataType) async {
    setState(() => _isLoading = true);

    try {
      print('>>> 请求权限: ${dataType.displayName}');

      // Apple Health需要用未授权的数据类型重新初始化来追加权限
      if (widget.platform == HealthPlatform.appleHealth) {
        // 收集所有未授权的权限（notDetermined状态）
        final notAuthorizedTypes = _supportedDataTypes.where((type) {
          final status = _permissionStatus[type];
          return status == null || status == HealthPermissionStatus.notDetermined;
        }).toList();

        print('>>> 未授权的权限: ${notAuthorizedTypes.map((t) => t.displayName).join(", ")}');

        if (notAuthorizedTypes.isEmpty) {
          setState(() => _isLoading = false);
          _showError('提示', '该权限可能已被拒绝，请前往系统设置手动开启');
          return;
        }

        // 只请求未授权的权限
        final result = await HealthBridge.initializeHealthPlatform(
          widget.platform,
          dataTypes: notAuthorizedTypes, // ✅ 只传入未授权的权限
          operations: [HealthDataOperation.read],
        );

        if (!mounted) return;

        if (result.isSuccess) {
          // 延迟后重新检查权限
          await Future.delayed(const Duration(milliseconds: 500));
          await _checkAllPermissions();
          
          // 通过读取数据验证授权是否生效
          await _verifyAuthorizationByReadingData(notAuthorizedTypes);
        } else {
          _showError('权限请求失败', result.message ?? '未知错误');
        }
      } else {
        // 其他平台使用requestPermissions
        final result = await HealthBridge.requestPermissions(
          platform: widget.platform,
          dataTypes: [dataType],
          operations: [HealthDataOperation.read],
          reason: '读取${dataType.displayName}数据',
        );

        if (!mounted) return;

        if (result.isSuccess) {
          await Future.delayed(const Duration(milliseconds: 500));
          await _checkAllPermissions();
          
          // 通过读取数据验证授权是否生效
          await _verifyAuthorizationByReadingData([dataType]);
        } else {
          _showError('权限请求失败', result.message ?? '未知错误');
        }
      }
    } catch (e) {
      print('!!! 请求权限异常: $e');
      _showError('请求权限异常', e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 通过读取数据验证授权是否真正生效（一键授权后调用）
  Future<void> _verifyAuthorizationByReadingData(List<HealthDataType> dataTypes) async {
    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      
      print('>>> 开始验证授权：读取最近7天数据...');
      
      // 记录有数据和无数据的类型
      final typesWithData = <HealthDataType>[];
      final typesWithoutData = <HealthDataType>[];
      
      // 强制读取每个数据类型的数据
      for (final dataType in dataTypes) {
        try {
          print('>>> 读取 ${dataType.displayName} 数据...');
          
          final result = await HealthBridge.readHealthData(
            platform: widget.platform,
            dataType: dataType,
            startDate: sevenDaysAgo,
            endDate: now,
          );
          
          print('>>> ${dataType.displayName}: ${result.data.length} 条数据');
          
          if (result.data.isNotEmpty) {
            typesWithData.add(dataType);
          } else {
            typesWithoutData.add(dataType);
          }
        } catch (e) {
          print('!!! 读取 ${dataType.displayName} 失败: $e');
          typesWithoutData.add(dataType);
        }
      }
      
      if (!mounted) return;
      
      // 判断授权是否真正生效
      if (typesWithData.isEmpty) {
        // 所有数据类型都没有数据，授权可能失败
        _showAuthorizationVerificationFailed(typesWithoutData);
      } else {
        // 至少有一个数据类型有数据，授权成功
        _showAuthorizationVerificationSuccess(typesWithData, typesWithoutData);
      }
    } catch (e) {
      print('!!! 验证授权失败: $e');
      // 不显示错误，静默失败
    }
  }
  


  /// 显示授权验证失败（所有数据都为空）
  void _showAuthorizationVerificationFailed(List<HealthDataType> emptyDataTypes) {
    final typeNames = emptyDataTypes.map((t) => t.displayName).join('、');
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: CupertinoColors.systemOrange,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('授权验证失败'),
          ],
        ),
        content: Text(
          '已请求 $typeNames 权限，但无法读取任何数据。\n\n'
          '可能原因：\n'
          '1. 授权未完全生效，请重试\n'
          '2. 设备中没有任何健康数据\n'
          '3. 系统限制了数据访问\n\n'
          '${widget.platform == HealthPlatform.appleHealth 
              ? '建议：\n• 打开"健康"应用，确认有数据\n• 检查"数据访问与设备"中的权限\n• 尝试重新授权' 
              : '建议：打开健康应用，确认有数据并重新授权'}',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              _requestAllPermissions(); // 重新授权
            },
            child: const Text('重新授权'),
          ),
        ],
      ),
    );
  }

  /// 显示授权验证成功
  void _showAuthorizationVerificationSuccess(
    List<HealthDataType> typesWithData,
    List<HealthDataType> typesWithoutData,
  ) {
    final successNames = typesWithData.map((t) => t.displayName).join('、');
    final emptyNames = typesWithoutData.map((t) => t.displayName).join('、');
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.checkmark_circle_fill,
              color: CupertinoColors.systemGreen,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('授权成功'),
          ],
        ),
        content: Text(
          '已成功读取到数据，授权生效！\n\n'
          '✓ 有数据：$successNames\n'
          '${typesWithoutData.isNotEmpty ? '\n○ 暂无数据：$emptyNames\n（设备可能未记录这些数据）' : ''}',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }
  


  /// 跳转到数据详情页
  void _navigateToDataDetail(HealthDataType dataType) async {
    setState(() => _isLoading = true);
    
    try {
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 7));
      
      final result = await HealthBridge.readHealthData(
        platform: widget.platform,
        dataType: dataType,
        startDate: startDate,
        endDate: now,
      );
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      // 跳转到数据详情页
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => HealthDataDetailPage(
            platform: widget.platform,
            dataType: dataType,
            dataList: result.data,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('读取数据失败', e.toString());
    }
  }

  /// 处理权限项点击
  void _handlePermissionTap(HealthDataType dataType) {
    final status = _permissionStatus[dataType];

    if (status == HealthPermissionStatus.granted) {
      // 已授权，跳转到数据详情页
      _navigateToDataDetail(dataType);
    } else {
      // 未授权，请求权限
      _showRequestPermissionDialog(dataType);
    }
  }

  /// 显示请求权限对话框
  void _showRequestPermissionDialog(HealthDataType dataType) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('请求${dataType.displayName}权限'),
        content: Text(
          '需要授权才能读取${dataType.displayName}数据。\n\n'
          '${widget.platform == HealthPlatform.appleHealth ? "将请求所有未授权的权限。" : ""}',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              _requestPermission(dataType);
            },
            child: const Text('授权'),
          ),
        ],
      ),
    );
  }

  void _showError(String title, String message) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.platform.displayName),
        backgroundColor: CupertinoColors.systemBackground,
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(
                child: CupertinoActivityIndicator(radius: 14),
              )
            : !_isInitialized
                ? _buildInitializingView()
                : _buildPermissionList(),
      ),
    );
  }

  Widget _buildInitializingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle,
            size: 64,
            color: CupertinoColors.systemOrange.resolveFrom(context),
          ),
          const SizedBox(height: 16),
          const Text(
            '平台初始化中...',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '请稍候',
            style: TextStyle(
              fontSize: 15,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionList() {
    return CustomScrollView(
      slivers: [
        // 平台信息 - 精美header
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _getPlatformColor().withOpacity(0.15),
                  _getPlatformColor().withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getPlatformColor().withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getPlatformColor().withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _getPlatformIcon(),
                    size: 48,
                    color: _getPlatformColor(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.platform.displayName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '点击权限项进行授权或查看数据',
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                // 一键授权按钮
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  color: _getPlatformColor(),
                  borderRadius: BorderRadius.circular(16),
                  onPressed: _isLoading ? null : _requestAllPermissions,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.checkmark_shield_fill,
                        color: CupertinoColors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '一键授权所有权限',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 权限列表
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CupertinoListSection.insetGrouped(
              header: const Text('数据权限'),
              children: _supportedDataTypes
                  .map((dataType) => _buildPermissionTile(dataType))
                  .toList(),
            ),
          ),
        ),

        // 底部说明
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '• 绿色：已授权，点击查看数据\n'
              '• 灰色：未授权，点击进行授权\n'
              '• 红色：已拒绝，点击重新授权',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionTile(HealthDataType dataType) {
    final status = _permissionStatus[dataType];
    final isGranted = status == HealthPermissionStatus.granted;
    final isDenied = status == HealthPermissionStatus.denied;

    return CupertinoListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _getStatusColor(status).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          _getDataTypeIcon(dataType),
          color: _getStatusColor(status),
          size: 24,
        ),
      ),
      title: Text(
        dataType.displayName,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        _getStatusText(status),
        style: TextStyle(
          fontSize: 13,
          color: _getStatusColor(status),
        ),
      ),
      trailing: Icon(
        isGranted
            ? CupertinoIcons.chevron_right
            : isDenied
                ? CupertinoIcons.lock_fill
                : CupertinoIcons.lock,
        size: 20,
        color: _getStatusColor(status),
      ),
      onTap: () => _handlePermissionTap(dataType),
    );
  }

  IconData _getPlatformIcon() {
    switch (widget.platform) {
      case HealthPlatform.appleHealth:
        return CupertinoIcons.heart_fill;
      case HealthPlatform.huaweiHealth:
      case HealthPlatform.huaweiCloud:
        return CupertinoIcons.heart_circle_fill;
      default:
        return CupertinoIcons.heart;
    }
  }

  Color _getPlatformColor() {
    switch (widget.platform) {
      case HealthPlatform.appleHealth:
        return CupertinoColors.systemRed;
      case HealthPlatform.huaweiHealth:
      case HealthPlatform.huaweiCloud:
        return CupertinoColors.systemOrange;
      default:
        return CupertinoColors.systemBlue;
    }
  }

  IconData _getDataTypeIcon(HealthDataType dataType) {
    switch (dataType) {
      case HealthDataType.steps:
        return CupertinoIcons.person_fill;
      case HealthDataType.glucose:
        return CupertinoIcons.drop_fill;
      case HealthDataType.bloodPressure:
        return CupertinoIcons.heart_fill;
      case HealthDataType.height:
        return CupertinoIcons.arrow_up_down;
      case HealthDataType.weight:
        return CupertinoIcons.chart_bar_alt_fill; // 使用柱状图图标代替体重秤
      default:
        return CupertinoIcons.heart;
    }
  }

  Color _getStatusColor(HealthPermissionStatus? status) {
    switch (status) {
      case HealthPermissionStatus.granted:
        return CupertinoColors.systemGreen;
      case HealthPermissionStatus.denied:
        return CupertinoColors.systemRed;
      case HealthPermissionStatus.restricted:
        return CupertinoColors.systemGrey;
      case HealthPermissionStatus.notDetermined:
      case null:
        return CupertinoColors.systemGrey;
    }
  }

  String _getStatusText(HealthPermissionStatus? status) {
    switch (status) {
      case HealthPermissionStatus.granted:
        return '已授权 - 点击查看数据';
      case HealthPermissionStatus.denied:
        return '已拒绝 - 点击重新授权';
      case HealthPermissionStatus.restricted:
        return '受限制 - 系统限制访问';
      case HealthPermissionStatus.notDetermined:
      case null:
        return '未授权 - 点击进行授权';
    }
  }
}
