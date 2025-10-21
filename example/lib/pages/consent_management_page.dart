import 'package:flutter/material.dart';
import 'package:health_bridge/health_bridge.dart';

/// 授权管理页面
///
/// 演示三个授权管理API的使用：
/// 1. 查询隐私授权状态 - checkPrivacyAuthStatus()
/// 2. 查询用户授权权限 - getUserConsents()
/// 3. 取消授权 - revokeConsent()
class ConsentManagementPage extends StatefulWidget {
  const ConsentManagementPage({super.key});

  @override
  State<ConsentManagementPage> createState() => _ConsentManagementPageState();
}

class _ConsentManagementPageState extends State<ConsentManagementPage> {
  // 示例配置（实际使用时应该从安全存储中读取）
  final String _accessToken = 'your_access_token_here'; // 从 OAuth 流程获取
  final String _clientId = '108913819'; // 你的应用 ID

  // 状态变量
  PrivacyAuthStatus? _privacyStatus;
  UserConsentInfo? _consentInfo;
  bool _isLoading = false;
  String? _errorMessage;

  /// 检查隐私授权状态
  Future<void> _checkPrivacyStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = HuaweiCloudClient(
        accessToken: _accessToken,
        clientId: _clientId,
      );

      final status = await client.checkPrivacyAuthStatus();

      setState(() {
        _privacyStatus = status;
        _isLoading = false;
      });

      _showSnackBar(
        '隐私授权状态: ${status.description}',
        status.isAuthorized ? Colors.green : Colors.orange,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '查询失败: $e';
      });
      _showSnackBar('查询失败: $e', Colors.red);
    }
  }

  /// 查询用户授权权限
  Future<void> _getUserConsents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = HuaweiCloudClient(
        accessToken: _accessToken,
        clientId: _clientId,
      );

      final consentInfo = await client.getUserConsents(
        appId: _clientId,
        lang: 'zh-cn',
      );

      setState(() {
        _consentInfo = consentInfo;
        _isLoading = false;
      });

      _showSnackBar(
        '查询成功！已授权 ${consentInfo.scopeCount} 个权限',
        Colors.green,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '查询失败: $e';
      });
      _showSnackBar('查询失败: $e', Colors.red);
    }
  }

  /// 取消授权
  Future<void> _revokeConsent() async {
    // 确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认取消授权'),
        content: const Text(
          '取消授权后，将无法访问健康数据。\n'
          '数据将在3天后自动删除。\n\n'
          '确定要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = HuaweiCloudClient(
        accessToken: _accessToken,
        clientId: _clientId,
      );

      final success = await client.revokeConsent(
        appId: _clientId,
        deleteDataImmediately: false, // 保留3天
      );

      setState(() {
        _isLoading = false;
      });

      if (success) {
        _showSnackBar('✅ 授权已取消！数据将在3天后删除', Colors.green);

        // 清空状态
        setState(() {
          _privacyStatus = null;
          _consentInfo = null;
        });

        // 实际使用时，这里应该清除本地存储的 token
        // await secureStorage.delete(key: 'access_token');
        // await secureStorage.delete(key: 'refresh_token');
      } else {
        _showSnackBar('❌ 取消授权失败', Colors.red);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '操作失败: $e';
      });
      _showSnackBar('操作失败: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('授权管理'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 说明卡片
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Text(
                                '授权管理功能说明',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '本页面演示三个授权管理 API：\n'
                            '1️⃣ 隐私授权状态查询 - 检查用户是否开启了数据共享\n'
                            '2️⃣ 用户授权权限查询 - 查看已授权的具体权限列表\n'
                            '3️⃣ 取消授权 - 撤销所有健康数据访问权限',
                            style: TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber,
                                    size: 16, color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    '⚠️ 使用前请先完成 OAuth 授权，获取有效的 access_token',
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

                  const SizedBox(height: 24),

                  // API 1: 隐私授权状态查询
                  _buildApiSection(
                    title: '1️⃣ 隐私授权状态查询',
                    description: '检查用户是否在华为运动健康App中开启了数据共享授权',
                    buttonText: '查询隐私授权状态',
                    onPressed: _checkPrivacyStatus,
                    resultWidget: _privacyStatus != null
                        ? _buildPrivacyStatusResult()
                        : null,
                  ),

                  const SizedBox(height: 16),

                  // API 2: 用户授权权限查询
                  _buildApiSection(
                    title: '2️⃣ 用户授权权限查询',
                    description: '查看用户授权给应用的所有健康数据权限详情',
                    buttonText: '查询授权权限',
                    onPressed: _getUserConsents,
                    resultWidget:
                        _consentInfo != null ? _buildConsentInfoResult() : null,
                  ),

                  const SizedBox(height: 16),

                  // API 3: 取消授权
                  _buildApiSection(
                    title: '3️⃣ 取消授权',
                    description: '撤销用户对该应用的全部健康数据访问权限（数据将在3天后删除）',
                    buttonText: '取消授权',
                    onPressed: _revokeConsent,
                    buttonColor: Colors.red,
                    resultWidget: null,
                  ),

                  // 错误提示
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildApiSection({
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onPressed,
    Widget? resultWidget,
    Color? buttonColor,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor ?? Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(buttonText),
              ),
            ),
            if (resultWidget != null) ...[
              const SizedBox(height: 12),
              resultWidget,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyStatusResult() {
    Color statusColor;
    IconData statusIcon;

    switch (_privacyStatus!) {
      case PrivacyAuthStatus.authorized:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case PrivacyAuthStatus.notAuthorized:
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      case PrivacyAuthStatus.notHealthUser:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _privacyStatus!.description,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Opinion 值: ${_privacyStatus!.value}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentInfoResult() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 基本信息
          Row(
            children: [
              Icon(Icons.info, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '授权信息',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow('应用名称', _consentInfo!.appName),
          _buildInfoRow(
            '授权时间',
            '${_consentInfo!.authTime.year}-${_consentInfo!.authTime.month.toString().padLeft(2, '0')}-${_consentInfo!.authTime.day.toString().padLeft(2, '0')} '
                '${_consentInfo!.authTime.hour.toString().padLeft(2, '0')}:${_consentInfo!.authTime.minute.toString().padLeft(2, '0')}',
          ),
          _buildInfoRow('权限数量', '${_consentInfo!.scopeCount} 个'),

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),

          // 权限列表
          Text(
            '已授权的权限：',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade900,
            ),
          ),
          const SizedBox(height: 8),

          ..._consentInfo!.scopeDescriptions.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.value,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
