import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health_bridge/src/oauth/huawei_oauth_config.dart';
import 'huawei_oauth_webview_page.dart';
import 'cloud_data_reading_page.dart';
import '../services/huawei_auth_service.dart';

/// 华为 OAuth 测试页面（PKCE 模式）
class HuaweiOAuthTestPage extends StatefulWidget {
  const HuaweiOAuthTestPage({super.key});

  @override
  State<HuaweiOAuthTestPage> createState() => _HuaweiOAuthTestPageState();
}

class _HuaweiOAuthTestPageState extends State<HuaweiOAuthTestPage> {
  final _methodChannel = const MethodChannel('health_bridge');

  String? _authUrl;
  String? _code;
  String? _state;
  String? _accessToken;
  String? _idToken;
  String? _error;
  bool _isLoading = false;
  Map<String, dynamic>? _userInfo;

  // OAuth 配置（PKCE 模式 - 不需要 clientSecret）
  late final HuaweiOAuthConfig _config;
  late final HuaweiAuthService _authService;

  @override
  void initState() {
    super.initState();
    
    // 初始化 PKCE 配置
    _config = HuaweiOAuthConfig(
      clientId: '108913819',  // AGC oauth_client.client_id
      redirectUri: 'https://test-novocareapp.novocare.com.cn/api/app/huaweiKit/redirectUrl',
      scopes: [
        'openid',
        // 'https://www.huawei.com/healthkit/heightweight.read',
        'https://www.huawei.com/healthkit/bloodglucose.read',
        // 'https://www.huawei.com/healthkit/bloodpressure.read'
        'https://www.huawei.com/healthkit/step.read',
        // 'https://www.huawei.com/healthkit/step.write',  // 读取数据不需要写权限
      ],
      state: 'test_state_123451',
      codeChallengeMethod: 'S256', // 使用 S256 编码方法
    );
    
    // 初始化认证服务
    _authService = HuaweiAuthService(config: _config);
    
    debugPrint('=== PKCE 参数 ===');
    debugPrint('code_verifier: ${_config.codeVerifier.substring(0, 20)}...');
    debugPrint('code_challenge: ${_config.codeChallenge.substring(0, 20)}...');
    debugPrint('code_challenge_method: ${_config.codeChallengeMethod}');
    debugPrint('=================');
    
    // 监听回调
    _methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  @override
  void dispose() {
    _methodChannel.setMethodCallHandler(null);
    super.dispose();
  }

  // 处理原生层的回调
  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onOAuthResult') {
      final result = call.arguments as Map?;
      if (result != null) {
        final resultMap = Map<String, dynamic>.from(result);
        setState(() {
          _code = resultMap['code'] as String?;
          _state = resultMap['state'] as String?;
          _error = resultMap['error'] as String?;
          _isLoading = false;
        });

        if (_code != null) {
          _showMessage('授权成功！获取到 code');
          // 自动换取 Token
          await _exchangeToken(_code!);
        } else if (_error != null) {
          _showError('授权失败: $_error');
        }
      }
    }
  }

  // 用授权码换取 Access Token（PKCE 模式）
  Future<void> _exchangeToken(String code) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('=== 开始换取 Token (PKCE) ===');
      
      final result = await _authService.exchangeCodeForToken(code);

      setState(() {
        _isLoading = false;
        if (result.isSuccess) {
          _accessToken = result.accessToken;
          _idToken = result.idToken;
          _showMessage('✅ 成功获取 Access Token！');

          // 解析 ID Token 获取用户信息
          if (_idToken != null) {
            _userInfo = _authService.parseIdToken(_idToken!);
          }
        } else {
          _error = result.errorDescription ?? result.error;
          _showError('换取 Token 失败: $_error');
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
      _showError('换取 Token 异常: $e');
    }
  }

  // 开始授权流程
  Future<void> _startAuthorization() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _code = null;
      _state = null;
    });

    try {
      // 1. 生成授权 URL
      final authUrl = _config.buildAuthorizeUrl();
      setState(() {
        _authUrl = authUrl;
      });

      debugPrint('=== 授权 URL ===');
      debugPrint(authUrl);
      debugPrint('================');

      // 2. 使用 Flutter 导航到 WebView 页面
      if (!mounted) return;
      
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (context) => HuaweiOAuthWebViewPage(
            authUrl: authUrl,
            redirectUri: _config.redirectUri,
          ),
        ),
      );

      // 3. 处理返回结果
      if (!mounted) return;
      
      if (result != null) {
        final code = result['code'] as String?;
        final state = result['state'] as String?;
        final error = result['error'] as String?;
        
        setState(() {
          _code = code;
          _state = state;
          _error = error;
        });
        
        if (code != null) {
          _showMessage('✅ 授权成功！获取到 code');
          
          // 立即换取 Token（PKCE 模式）
          await _exchangeToken(code);
        } else if (error != null) {
          setState(() {
            _isLoading = false;
          });
          final errorDesc = result['error_description'] as String?;
          _showError('❌ 授权失败: $error${errorDesc != null ? '\n$errorDesc' : ''}');
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      _showError('发生错误: $e');
    }
  }

  void _showMessage(String message) {
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
        title: const Text('华为 OAuth 测试'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 配置信息
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'OAuth 配置',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'PKCE 模式',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Client ID', _config.clientId),
                    _buildInfoRow('Redirect URI', _config.redirectUri),
                    _buildInfoRow('Scopes', _config.scopes.join(', ')),
                    _buildInfoRow('State', _config.state ?? 'N/A'),
                    const Divider(height: 24),
                    const Text(
                      'PKCE 参数',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'code_challenge_method',
                      _config.codeChallengeMethod,
                    ),
                    _buildInfoRow(
                      'code_challenge',
                      '${_config.codeChallenge.substring(0, 30)}...',
                    ),
                    _buildInfoRow(
                      'code_verifier',
                      '${_config.codeVerifier.substring(0, 30)}... (${_config.codeVerifier.length} 字符)',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 开始授权按钮
            ElevatedButton(
              onPressed: _isLoading ? null : _startAuthorization,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      '开始授权',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 24),

            // 授权 URL
            if (_authUrl != null) ...[
              const Text(
                '授权 URL:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _authUrl!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 授权结果 - Code
            if (_code != null) ...[
              const Text(
                '✅ 授权成功！',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Authorization Code:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: SelectableText(
                  _code!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_state != null) ...[
                const Text(
                  'State:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _state!,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
            ],

            // Access Token
            if (_accessToken != null) ...[
              const Text(
                '✅ Access Token 获取成功！',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Access Token:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      '${_accessToken!.substring(0, 50)}...',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 去云侧读取数据按钮
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CloudDataReadingPage(
                        accessToken: _accessToken,
                        clientId: _config.clientId,  // 传递 clientId
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.cloud_download),
                label: const Text('去云侧读取数据'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ID Token 和用户信息
            if (_idToken != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ID Token (用户信息):',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_userInfo != null) ...[
                      ..._userInfo!.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Text(
                                '${entry.key}: ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${entry.value}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ] else ...[
                      SelectableText(
                        _idToken!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 错误信息
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(
                  '错误: $_error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 8),

            // 使用说明
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '使用说明:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. 点击"开始授权"按钮\n'
                      '2. 在 WebView 中打开华为登录页面\n'
                      '3. 登录并授权后会自动返回\n'
                      '4. 应用会显示获取到的 Code\n\n'
                      '注意: 使用 WebView 方式，无需配置 Deep Link',
                      style: TextStyle(fontSize: 14),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
