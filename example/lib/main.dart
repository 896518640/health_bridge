import 'package:flutter/material.dart';
import 'package:health_bridge/health_bridge.dart';
import 'pages/permission_management_page.dart';
import 'pages/data_reading_page.dart';
import 'pages/huawei_oauth_test_page.dart';

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
    return MaterialApp(
      title: 'Health Bridge Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
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
  HealthPlatform? _selectedPlatform;
  bool _isLoading = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initPlatform();
  }

  /// 初始化平台
  Future<void> _initPlatform() async {
    print('>>> 开始初始化平台...');
    setState(() => _isLoading = true);

    try {
      print('>>> 获取平台版本...');
      final version = await HealthBridge.getPlatformVersion() ?? '未知';
      print('>>> 平台版本: $version');

      print('>>> 获取可用健康平台...');
      final platforms = await HealthBridge.getAvailableHealthPlatforms();
      print('>>> 可用平台数量: ${platforms.length}');
      for (var platform in platforms) { 
        print('    - ${platform.displayName} (${platform.key})');
      }

      if (!mounted) return;

      setState(() {
        _platformVersion = version;
        _availablePlatforms = platforms;
        if (platforms.isNotEmpty) {
          _selectedPlatform = platforms.first;
          print('>>> 默认选择平台: ${platforms.first.displayName}');
        }
      });
      print('>>> 平台初始化完成!');
    } catch (e) {
      print('!!! 初始化失败: $e');
      _showError('初始化失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 初始化健康平台
  Future<void> _initializeHealthPlatform() async {
    if (_selectedPlatform == null) return;

    print('>>> 开始初始化健康平台: ${_selectedPlatform!.displayName}');
    setState(() => _isLoading = true);

    try {
      final result = await HealthBridge.initializeHealthPlatform(
        _selectedPlatform!,
      );

      print('>>> 初始化结果: ${result.status}');
      print('>>> 消息: ${result.message}');

      if (!mounted) return;

      if (result.isSuccess) {
        setState(() => _isInitialized = true);
        print('>>> ✓ ${_selectedPlatform!.displayName} 初始化成功!');
        _showSuccess('${_selectedPlatform!.displayName} 初始化成功');
      } else {
        print('!!! 初始化失败: ${result.message}');
        _showError('初始化失败: ${result.message}');
      }
    } catch (e) {
      print('!!! 初始化异常: $e');
      _showError('初始化异常: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 断开连接
  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('断开连接'),
        content: Text(
          '确定要断开 ${_selectedPlatform?.displayName} 的连接吗？\n\n'
          '注意：这只是断开应用内的连接，不会取消系统授权。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await HealthBridge.disconnect();

      if (!mounted) return;

      setState(() => _isInitialized = false);
      _showSuccess('已断开连接');
    } catch (e) {
      _showError('断开连接失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 打开权限管理页面
  void _openPermissionManagement() {
    if (_selectedPlatform == null) {
      _showError('请先选择平台');
      return;
    }

    if (!_isInitialized) {
      _showError('请先初始化平台');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PermissionManagementPage(
          platform: _selectedPlatform!,
        ),
      ),
    );
  }

  /// 打开数据读取页面
  void _openDataReading() {
    if (_selectedPlatform == null) {
      _showError('请先选择平台');
      return;
    }

    if (!_isInitialized) {
      _showError('请先初始化平台');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DataReadingPage(
          platform: _selectedPlatform!,
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
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
        title: const Text('Health Bridge Demo'),
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 平台信息卡片
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '平台信息',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 8),
                          _buildInfoRow('系统版本', _platformVersion),
                          _buildInfoRow(
                            '可用平台',
                            _availablePlatforms.isEmpty
                                ? '无'
                                : _availablePlatforms
                                    .map((p) => p.displayName)
                                    .join(', '),
                          ),
                          if (_selectedPlatform != null)
                            _buildInfoRow(
                              '当前平台',
                              _selectedPlatform!.displayName,
                            ),
                          _buildInfoRow(
                            '状态',
                            _isInitialized ? '已初始化' : '未初始化',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 平台初始化卡片
                  Card(
                    color: _isInitialized
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isInitialized
                                    ? Icons.check_circle
                                    : Icons.warning_amber,
                                color: _isInitialized
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isInitialized ? '平台已初始化' : '平台未初始化',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _isInitialized
                                      ? Colors.green.shade900
                                      : Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (!_isInitialized)
                            const Text(
                              '请先初始化平台，才能使用权限管理和数据读取功能',
                              style: TextStyle(fontSize: 12),
                            )
                          else
                            const Text(
                              '平台已就绪，可以进行权限管理和数据读取',
                              style: TextStyle(fontSize: 12),
                            ),
                          const SizedBox(height: 16),
                          if (!_isInitialized)
                            ElevatedButton.icon(
                              onPressed: _selectedPlatform == null
                                  ? null
                                  : _initializeHealthPlatform,
                              icon: const Icon(Icons.power_settings_new),
                              label: const Text('初始化平台'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: _disconnect,
                              icon: const Icon(Icons.power_off),
                              label: const Text('断开连接'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 功能入口
                  Text(
                    '功能入口',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),

                  // 权限管理
                  Card(
                    elevation: 2,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.security,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      title: const Text(
                        '权限管理',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        '管理步数、血糖、血压的读写权限\n支持授权和查看取消授权指引',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: _openPermissionManagement,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 数据读取
                  Card(
                    elevation: 2,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.download,
                          color: Colors.green.shade700,
                        ),
                      ),
                      title: const Text(
                        '数据读取',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        '读取步数、血糖、血压的今日数据\n点击可查看详细数据列表',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: _openDataReading,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // OAuth 测试
                  Card(
                    elevation: 2,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.login,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      title: const Text(
                        'OAuth 授权测试',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        '测试华为帐号 OAuth 授权流程',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const HuaweiOAuthTestPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 使用说明
                  Card(
                    color: Colors.grey.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.help_outline,
                                  color: Colors.grey.shade700),
                              const SizedBox(width: 8),
                              Text(
                                '使用说明',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '1. 首先点击"初始化平台"按钮\n'
                            '2. 进入"权限管理"申请所需数据类型的权限\n'
                            '3. 进入"数据读取"读取健康数据\n'
                            '4. 点击数据卡片可查看详细信息',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
