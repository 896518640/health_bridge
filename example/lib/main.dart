import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:health_bridge/health_bridge.dart';
import 'pages/platform_permission_page.dart';
import 'pages/huawei_oauth_test_page_v2.dart';

void main() {
  print('========================================');
  print('Health Bridge Demo 应用启动');
  print('========================================');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Health Bridge',
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        brightness: Brightness.light,
      ),
      home: const HomePage(),
      localizationsDelegates: const [
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _platformVersion = '未知';
  List<HealthPlatform> _availablePlatforms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initPlatform();
  }

  /// 初始化平台信息
  Future<void> _initPlatform() async {
    print('>>> 开始获取平台信息...');
    setState(() => _isLoading = true);

    try {
      final version = await HealthBridge.getPlatformVersion() ?? '未知';
      final platforms = await HealthBridge.getAvailableHealthPlatforms();
      
      print('>>> 平台版本: $version');
      print('>>> 可用平台数量: ${platforms.length}');
      for (var platform in platforms) { 
        print('    - ${platform.displayName} (${platform.key})');
      }

      if (!mounted) return;

      setState(() {
        _platformVersion = version;
        _availablePlatforms = platforms;
      });
      
      print('>>> 平台信息获取完成!');
    } catch (e) {
      print('!!! 获取平台信息失败: $e');
      _showError('获取平台信息失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 打开平台权限页面（优化：先授权再进入）
  void _openPlatformPermission(HealthPlatform platform) async {
    // 对于 Apple Health，先在主页面完成授权，再进入权限管理页
    if (platform == HealthPlatform.appleHealth) {
      await _initializeAppleHealth(platform);
    } else {
      // 其他平台直接进入
      _navigateToPlatformPermissionPage(platform);
    }
  }

  /// 初始化 Apple Health（在主页面完成授权）
  Future<void> _initializeAppleHealth(HealthPlatform platform) async {
    // 显示加载对话框
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CupertinoAlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(radius: 14),
            SizedBox(height: 16),
            Text('正在请求授权...'),
          ],
        ),
      ),
    );

    try {
      // 定义需要授权的数据类型
      final dataTypes = [
        HealthDataType.steps,
        HealthDataType.glucose,
        HealthDataType.bloodPressure,
        HealthDataType.height,
        HealthDataType.weight,
      ];

      print('>>> 开始初始化 Apple Health');
      print('>>> 数据类型: ${dataTypes.map((t) => t.displayName).join(", ")}');

      // 初始化并请求授权
      final result = await HealthBridge.initializeHealthPlatform(
        platform,
        dataTypes: dataTypes,
        operations: [HealthDataOperation.read],
      );

      // 关闭加载对话框
      if (!mounted) return;
      Navigator.of(context).pop();

      if (result.isSuccess) {
        print('>>> Apple Health 初始化成功');
        
        // 延迟一下，让用户完成系统授权弹窗
        await Future.delayed(const Duration(milliseconds: 500));
        
        // 进入权限管理页面
        _navigateToPlatformPermissionPage(platform);
      } else {
        print('!!! 初始化失败: ${result.message}');
        _showError('初始化失败: ${result.message ?? "未知错误"}');
      }
    } catch (e) {
      // 关闭加载对话框
      if (mounted) {
        Navigator.of(context).pop();
      }
      print('!!! 初始化异常: $e');
      _showError('初始化异常: $e');
    }
  }

  /// 跳转到平台权限页面
  void _navigateToPlatformPermissionPage(HealthPlatform platform) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => PlatformPermissionPage(
          platform: platform,
          skipInitialization: platform == HealthPlatform.appleHealth, // Apple Health 已在主页面初始化
        ),
      ),
    );
  }

  /// 打开华为OAuth授权页面
  void _openHuaweiOAuth() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const HuaweiOAuthTestPageV2(),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('错误'),
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
      navigationBar: const CupertinoNavigationBar(
        middle: Text('健康数据'),
        backgroundColor: CupertinoColors.systemBackground,
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(
                child: CupertinoActivityIndicator(radius: 14),
              )
            : CustomScrollView(
                slivers: [
                  // 平台信息
                  SliverToBoxAdapter(
                    child: _buildPlatformInfoSection(),
                  ),
                  
                  // 可用平台列表
                  SliverToBoxAdapter(
                    child: _buildPlatformListSection(),
                  ),
                ],
              ),
      ),
    );
  }

  /// 平台信息区域
  Widget _buildPlatformInfoSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              CupertinoColors.systemBlue.withOpacity(0.1),
              CupertinoColors.systemPurple.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: CupertinoColors.systemGrey5,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    CupertinoIcons.device_phone_portrait,
                    color: CupertinoColors.systemBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '设备信息',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _platformVersion,
                        style: const TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.checkmark_seal_fill,
                    color: CupertinoColors.systemGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _availablePlatforms.isEmpty
                          ? '暂无可用平台'
                          : '可用: ${_availablePlatforms.map((p) => p.displayName).join('、')}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 可用平台列表
  Widget _buildPlatformListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 端侧健康平台
        if (_availablePlatforms.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              '健康平台',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: _availablePlatforms
                  .map((platform) => _buildPlatformTile(platform))
                  .toList(),
            ),
          ),
        ] else
          _buildEmptyPlatformSection(),

        // 华为云侧OAuth入口
        _buildHuaweiCloudSection(),
        
        const SizedBox(height: 32),
      ],
    );
  }

  /// 空平台提示
  Widget _buildEmptyPlatformSection() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              CupertinoIcons.info_circle,
              size: 48,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            const SizedBox(height: 12),
            Text(
              '当前设备没有可用的健康平台',
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 平台列表项
  Widget _buildPlatformTile(HealthPlatform platform) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getPlatformColor(platform).withOpacity(0.08),
            _getPlatformColor(platform).withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getPlatformColor(platform).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: CupertinoListTile(
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _getPlatformColor(platform).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _getPlatformIcon(platform),
            color: _getPlatformColor(platform),
            size: 28,
          ),
        ),
        title: Text(
          platform.displayName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          _getPlatformDescription(platform),
          style: const TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
        trailing: const CupertinoListTileChevron(),
        onTap: () => _openPlatformPermission(platform),
      ),
    );
  }

  /// 华为云侧功能区
  Widget _buildHuaweiCloudSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                const Text(
                  '云侧功能',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        CupertinoColors.systemOrange.withOpacity(0.8),
                        CupertinoColors.systemOrange.withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '仅华为',
                    style: TextStyle(
                      fontSize: 10,
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CupertinoColors.systemPurple.withOpacity(0.08),
                  CupertinoColors.systemIndigo.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: CupertinoColors.systemPurple.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: CupertinoListTile(
              leading: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.systemPurple.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.cloud,
                  color: CupertinoColors.systemPurple,
                  size: 28,
                ),
              ),
              title: const Text(
                'OAuth 授权管理',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                '华为帐号授权 + 云端数据读取',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              trailing: const CupertinoListTileChevron(),
              onTap: _openHuaweiOAuth,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPlatformIcon(HealthPlatform platform) {
    switch (platform) {
      case HealthPlatform.appleHealth:
        return CupertinoIcons.heart_fill;
      case HealthPlatform.huaweiHealth:
        return CupertinoIcons.heart_circle_fill;
      default:
        return CupertinoIcons.heart;
    }
  }

  Color _getPlatformColor(HealthPlatform platform) {
    switch (platform) {
      case HealthPlatform.appleHealth:
        return CupertinoColors.systemRed;
      case HealthPlatform.huaweiHealth:
        return CupertinoColors.systemOrange;
      default:
        return CupertinoColors.systemBlue;
    }
  }

  String _getPlatformDescription(HealthPlatform platform) {
    switch (platform) {
      case HealthPlatform.appleHealth:
        return '步数、血糖、血压、身高、体重';
      case HealthPlatform.huaweiHealth:
        return '步数、血糖、血压';
      default:
        return '健康数据管理';
    }
  }
}
