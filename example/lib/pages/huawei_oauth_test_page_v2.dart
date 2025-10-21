import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:health_bridge/health_bridge.dart';
import 'cloud_data_reading_page.dart';

/// 华为 OAuth 测试页面 V2 - 使用半托管模式
///
/// 这个版本使用 HuaweiOAuthHelper（Layer 2 半托管 API）
/// 相比旧版本，代码更简洁，职责更清晰
class HuaweiOAuthTestPageV2 extends StatefulWidget {
  const HuaweiOAuthTestPageV2({super.key});

  @override
  State<HuaweiOAuthTestPageV2> createState() => _HuaweiOAuthTestPageV2State();
}

class _HuaweiOAuthTestPageV2State extends State<HuaweiOAuthTestPageV2> {
  // 🔧 使用插件提供的 OAuth 辅助类
  late final HuaweiOAuthHelper _oauthHelper;

  // OAuth 结果
  HuaweiOAuthResult? _oauthResult;
  Map<String, dynamic>? _userInfo;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // 初始化 OAuth 辅助类
    _oauthHelper = HuaweiOAuthHelper(
      config: HuaweiOAuthConfig(
        clientId: '108913819',
        redirectUri: 'https://test-novocareapp.novocare.com.cn/api/app/huaweiKit/redirectUrl',
        scopes: [
          'openid',
          'https://www.huawei.com/healthkit/bloodglucose.read',
          'https://www.huawei.com/healthkit/bloodpressure.read',
          'https://www.huawei.com/healthkit/step.read',
        ],
        state: 'state_${DateTime.now().millisecondsSinceEpoch}',
        codeChallengeMethod: 'S256',
      ),
    );

    debugPrint('[OAuth V2] 初始化完成');
    debugPrint('[OAuth V2] Client ID: ${_oauthHelper.config.clientId}');
    debugPrint('[OAuth V2] Redirect URI: ${_oauthHelper.redirectUri}');
  }

  /// 开始授权（使用自定义 WebView）
  Future<void> _startAuthorization() async {
    setState(() => _isLoading = true);

    try {
      // 1️⃣ 生成授权 URL
      final authUrl = _oauthHelper.generateAuthUrl();
      debugPrint('[OAuth V2] 授权 URL 已生成');

      // 2️⃣ 打开自定义 WebView 页面
      if (!mounted) return;

      final result = await Navigator.of(context).push<HuaweiOAuthResult>(
        MaterialPageRoute(
          builder: (context) => _OAuthWebViewPage(
            authUrl: authUrl,
            oauthHelper: _oauthHelper,
          ),
        ),
      );

      // 3️⃣ 处理结果
      if (!mounted) return;

      if (result != null && result.isSuccess) {
        setState(() {
          _oauthResult = result;
          _isLoading = false;
        });

        // 解析 ID Token
        if (result.idToken != null) {
          final userInfo = _oauthHelper.parseIdToken(result.idToken!);
          setState(() => _userInfo = userInfo);
        }

        // 这里应该保存 Token 到安全存储
        // await myTokenStorage.save(result);

        _showSuccess('✅ 授权成功！Token 已获取');
      } else if (result != null && result.hasError) {
        setState(() => _isLoading = false);
        _showError('❌ 授权失败: ${result.error}');
      } else {
        setState(() => _isLoading = false);
        debugPrint('[OAuth V2] 用户取消授权');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('❌ 授权异常: $e');
      debugPrint('[OAuth V2] 授权异常: $e');
    }
  }

  /// 刷新 Token
  /// ⚠️ 暂时注释掉：华为官方接口文档有问题，待后续修复
  Future<void> _refreshToken() async {
    _showError('⚠️ 刷新功能暂时禁用（官方接口文档问题）');
    return;

    // TODO: 等华为官方接口文档修复后再启用
    /*
    if (_oauthResult?.refreshToken == null) {
      _showError('⚠️ 没有 Refresh Token');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _oauthHelper.refreshToken(_oauthResult!.refreshToken!);

      if (result.isSuccess) {
        setState(() {
          _oauthResult = result;
          _isLoading = false;
        });
        _showSuccess('✅ Token 刷新成功！');
      } else {
        setState(() => _isLoading = false);
        _showError('❌ 刷新失败: ${result.error}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('❌ 刷新异常: $e');
    }
    */
  }

  /// 清除 Token
  void _clearToken() {
    setState(() {
      _oauthResult = null;
      _userInfo = null;
    });
    _showSuccess('✅ Token 已清除');
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
        title: const Text('华为 OAuth V2'),
        backgroundColor: Colors.purple,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '半托管模式',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
                    color: Colors.purple.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.purple.shade700),
                              const SizedBox(width: 8),
                              Text(
                                '🎯 半托管模式优势',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '• 插件提供核心逻辑（URL 生成、PKCE、Token 交换）\n'
                            '• App 可自定义 WebView UI 和业务逻辑\n'
                            '• 代码更简洁，职责更清晰\n'
                            '• 完全控制 Token 存储方式',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 开始授权按钮
                  ElevatedButton.icon(
                    onPressed: _startAuthorization,
                    icon: const Icon(Icons.login),
                    label: const Text('开始授权（自定义 WebView）'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Access Token 显示
                  if (_oauthResult?.accessToken != null) ...[
                    Text(
                      '✅ Access Token',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            '${_oauthResult!.accessToken!}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '过期时间: ${_oauthResult!.expiresIn} 秒',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          if (_oauthResult!.scope != null)
                            Text(
                              'Scope: ${_oauthResult!.scope}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 操作按钮
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _refreshToken,
                            icon: const Icon(Icons.refresh, size: 20),
                            label: const Text('刷新 Token'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _clearToken,
                            icon: const Icon(Icons.delete, size: 20),
                            label: const Text('清除 Token'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 去云侧读取数据按钮
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => CloudDataReadingPage(
                              accessToken: _oauthResult!.accessToken,
                              clientId: _oauthHelper.config.clientId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('去云侧读取数据'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],

                  // 用户信息显示
                  if (_userInfo != null) ...[
                    Text(
                      '👤 用户信息 (ID Token)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _userInfo!.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    '${entry.key}:',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: SelectableText(
                                    '${entry.value}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],

                  // 代码对比说明
                  Card(
                    color: Colors.amber.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.code, color: Colors.amber.shade700),
                              const SizedBox(width: 8),
                              Text(
                                '💡 代码简化对比',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '旧版本（完全手动）：\n'
                            '• 需要手动管理 PKCE 参数\n'
                            '• 需要手动构建授权 URL\n'
                            '• 需要手动解析回调 URL\n'
                            '• 需要手动调用 Token 交换 API\n'
                            '• 代码量 600+ 行\n\n'
                            '新版本（半托管）：\n'
                            '• ✅ HuaweiOAuthHelper 自动处理核心逻辑\n'
                            '• ✅ 只需关注 WebView UI 定制\n'
                            '• ✅ 代码量减少 70%\n'
                            '• ✅ 更易维护和扩展',
                            style: TextStyle(fontSize: 12, height: 1.5),
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
}

/// 自定义 WebView 页面
class _OAuthWebViewPage extends StatefulWidget {
  final String authUrl;
  final HuaweiOAuthHelper oauthHelper;

  const _OAuthWebViewPage({
    required this.authUrl,
    required this.oauthHelper,
  });

  @override
  State<_OAuthWebViewPage> createState() => _OAuthWebViewPageState();
}

class _OAuthWebViewPageState extends State<_OAuthWebViewPage> {
  late final WebViewController _webController;

  int _loadingProgress = 0;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent('HealthBridge/1.0 Flutter')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('[WebView] 页面开始加载: $url');

            // ✅ 使用插件检查是否是回调 URL
            if (widget.oauthHelper.isCallbackUrl(url)) {
              debugPrint('[WebView] 🎯 检测到回调 URL');
              _handleCallback(url);
            }
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
            debugPrint('[WebView] ✅ 页面加载完成');
          },
          onProgress: (progress) {
            setState(() => _loadingProgress = progress);
          },
          onWebResourceError: (error) {
            setState(() => _isLoading = false);
            debugPrint('[WebView] ❌ 加载错误: ${error.description}');
          },
          onNavigationRequest: (request) {
            final url = request.url;

            // ✅ 使用插件检查是否是回调 URL（包含 code 参数时拦截）
            if (widget.oauthHelper.isCallbackUrl(url)) {
              final uri = Uri.parse(url);
              if (uri.queryParameters.containsKey('code') ||
                  uri.queryParameters.containsKey('error')) {
                debugPrint('[WebView] 🚫 拦截回调 URL');
                _handleCallback(url);
                return NavigationDecision.prevent;
              }
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  /// 处理回调 URL
  Future<void> _handleCallback(String callbackUrl) async {
    if (_isProcessing) return; // 防止重复处理
    setState(() => _isProcessing = true);

    try {
      // ✅ 使用插件解析回调参数
      final params = widget.oauthHelper.parseCallback(callbackUrl);

      if (params == null) {
        debugPrint('[WebView] ❌ 解析回调失败');
        if (!mounted) return;
        Navigator.of(context).pop(
          HuaweiOAuthResult(
            error: 'parse_error',
            errorDescription: '解析回调 URL 失败',
          ),
        );
        return;
      }

      // 检查是否有错误
      if (params['error'] != null) {
        final error = params['error']!;
        final description = params['error_description'] ?? '未知错误';
        debugPrint('[WebView] ❌ 授权错误: $error');

        if (!mounted) return;
        Navigator.of(context).pop(
          HuaweiOAuthResult(error: error, errorDescription: description),
        );
        return;
      }

      // 获取授权码
      final code = params['code'];
      if (code == null) {
        debugPrint('[WebView] ❌ 未获取到授权码');
        if (!mounted) return;
        Navigator.of(context).pop(
          HuaweiOAuthResult(
            error: 'no_code',
            errorDescription: '未获取到授权码',
          ),
        );
        return;
      }

      debugPrint('[WebView] ✅ 获取到授权码');

      // 显示加载中
      setState(() {
        _isLoading = true;
        _loadingProgress = 0;
      });

      try {
        // ✅ 使用插件交换 Token
        final result = await widget.oauthHelper.exchangeToken(code);

        if (!mounted) return;

        if (result.isSuccess) {
          debugPrint('[WebView] ✅ Token 交换成功');
          Navigator.of(context).pop(result);
        } else {
          debugPrint('[WebView] ❌ Token 交换失败: ${result.error}');
          Navigator.of(context).pop(result);
        }
      } catch (e) {
        debugPrint('[WebView] ❌ Token 交换异常: $e');

        if (!mounted) return;
        Navigator.of(context).pop(
          HuaweiOAuthResult(
            error: 'exchange_error',
            errorDescription: 'Token 交换异常: $e',
          ),
        );
      }
    } catch (e) {
      debugPrint('[WebView] ❌ 处理回调异常: $e');

      if (!mounted) return;
      Navigator.of(context).pop(
        HuaweiOAuthResult(
          error: 'callback_error',
          errorDescription: '处理回调异常: $e',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('华为账号授权'),
        backgroundColor: Colors.purple,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            debugPrint('[WebView] 用户取消授权');
            Navigator.of(context).pop(null);
          },
        ),
      ),
      body: Column(
        children: [
          // 进度条
          if (_isLoading && _loadingProgress > 0)
            LinearProgressIndicator(
              value: _loadingProgress / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(Colors.purple),
            ),

          // 加载提示
          if (_isProcessing)
            Container(
              color: Colors.purple.shade50,
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '正在换取 Token...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // WebView
          Expanded(
            child: WebViewWidget(controller: _webController),
          ),
        ],
      ),
    );
  }
}
