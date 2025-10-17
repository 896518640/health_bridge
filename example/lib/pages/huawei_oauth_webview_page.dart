import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 华为 OAuth WebView 页面 (Flutter 实现)
/// 用于在 WebView 中完成华为账号授权
class HuaweiOAuthWebViewPage extends StatefulWidget {
  final String authUrl;
  final String redirectUri;

  const HuaweiOAuthWebViewPage({
    Key? key,
    required this.authUrl,
    required this.redirectUri,
  }) : super(key: key);

  @override
  State<HuaweiOAuthWebViewPage> createState() => _HuaweiOAuthWebViewPageState();
}

class _HuaweiOAuthWebViewPageState extends State<HuaweiOAuthWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    
    print('[Flutter WebView] ========================================');
    print('[Flutter WebView] 🚀🚀🚀 WebView 页面初始化 v2.0 🚀🚀🚀');
    print('[Flutter WebView] ========================================');
    print('[Flutter WebView] authUrl: ${widget.authUrl}');
    print('[Flutter WebView] authUrl 长度: ${widget.authUrl.length}');
    print('[Flutter WebView] redirectUri: ${widget.redirectUri}');
    print('[Flutter WebView] 当前时间: ${DateTime.now()}');
    print('[Flutter WebView] ========================================');
    
    _initializeWebView();
  }

  void _initializeWebView() {
    print('[Flutter WebView] 🔧 开始配置 WebViewController...');
    
    const userAgent = 'Mozilla/5.0 (Linux; HarmonyOS) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36';
    print('[Flutter WebView] 📱 设置 UserAgent: $userAgent');
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent(userAgent)
      ..enableZoom(true)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('[Flutter WebView] 📄 页面开始加载: $url');
            
            // 检查是否是回调 URL
            if (url.startsWith(widget.redirectUri)) {
              print('[Flutter WebView] 🎯 检测到回调 URL!');
              _handleCallback(url);
            }
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            print('[Flutter WebView] ✅ 页面加载完成: $url');
          },
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress;
            });
            if (progress % 20 == 0) {
              print('[Flutter WebView] 📊 加载进度: $progress%');
            }
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _errorMessage = '加载失败: ${error.description}';
            });
            print('[Flutter WebView] ❌❌❌ 加载错误 ❌❌❌');
            print('[Flutter WebView]    错误类型: ${error.errorType}');
            print('[Flutter WebView]    错误码: ${error.errorCode}');
            print('[Flutter WebView]    错误信息: ${error.description}');
            print('[Flutter WebView]    失败URL: ${error.url}');
            print('[Flutter WebView]    是否主框架: ${error.isForMainFrame}');
            
            // 华为官方文档提到的常见错误码：
            // -102: 网络连接失败
            // -200: SSL握手失败  
            // -300: 证书校验失败
            if (error.errorCode == -102) {
              print('[Flutter WebView] 🔴 网络连接失败 - 检查网络权限和连接');
            } else if (error.errorCode == -200) {
              print('[Flutter WebView] 🔴 SSL握手失败 - 检查证书配置');
            } else if (error.errorCode == -300) {
              print('[Flutter WebView] 🔴 证书校验失败 - 检查SSL配置');
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            print('[Flutter WebView] 🔍 导航请求: $url');
            print('[Flutter WebView] 🔍 isMainFrame: ${request.isMainFrame}');
            
            // 只拦截真正的回调 URL（包含 code 或 error 参数）
            if (url.startsWith(widget.redirectUri)) {
              final uri = Uri.parse(url);
              final hasCode = uri.queryParameters.containsKey('code');
              final hasError = uri.queryParameters.containsKey('error');
              
              if (hasCode || hasError) {
                // 这是真正的回调 URL，包含授权结果
                print('[Flutter WebView] 🚫 拦截回调 URL（包含授权结果）');
                print('[Flutter WebView]    code: ${uri.queryParameters['code'] != null ? "存在" : "不存在"}');
                print('[Flutter WebView]    error: ${uri.queryParameters['error'] ?? "无"}');
                _handleCallback(url);
                return NavigationDecision.prevent;
              } else {
                // 这可能是授权确认页面或其他中间页面，允许导航
                print('[Flutter WebView] ⏭️ 允许导航到 redirect_uri 域名的页面（等待用户操作）');
                print('[Flutter WebView]    → 可能是授权确认页面');
                return NavigationDecision.navigate;
              }
            }
            
            // 允许所有华为域名
            if (url.contains('huawei.com')) {
              print('[Flutter WebView] ✅ 允许华为域名: $url');
              return NavigationDecision.navigate;
            }
            
            print('[Flutter WebView] ⚠️ 允许导航到: $url');
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  /// 处理回调 URL，解析参数
  void _handleCallback(String url) {
    print('[Flutter WebView] ========== 处理回调 ==========');
    print('[Flutter WebView] 回调 URL: $url');
    
    try {
      final uri = Uri.parse(url);
      final code = uri.queryParameters['code'];
      final state = uri.queryParameters['state'];
      final error = uri.queryParameters['error'];
      final errorDescription = uri.queryParameters['error_description'];
      
      print('[Flutter WebView] code: $code');
      print('[Flutter WebView] state: $state');
      print('[Flutter WebView] error: $error');
      
      // 返回结果
      if (mounted) {
        Navigator.of(context).pop({
          'code': code,
          'state': state,
          'error': error,
          'error_description': errorDescription,
        });
      }
    } catch (e) {
      print('[Flutter WebView] ❌ 解析回调 URL 失败: $e');
      if (mounted) {
        Navigator.of(context).pop({
          'error': 'parse_error',
          'error_description': e.toString(),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('华为账号授权27722'),
        backgroundColor: const Color(0xFFFF6200),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            print('[Flutter WebView] 用户点击返回');
            Navigator.of(context).pop({
              'error': 'user_cancelled',
              'error_description': '用户取消授权',
            });
          },
        ),
      ),
      body: Column(
        children: [
          // 加载进度条
          if (_isLoading && _loadingProgress > 0)
            LinearProgressIndicator(
              value: _loadingProgress / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6200)),
            ),
          
          // WebView 或错误信息
          Expanded(
            child: _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _errorMessage = null;
                              _isLoading = true;
                            });
                            _initializeWebView();
                          },
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  )
                : WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}

