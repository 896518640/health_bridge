import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:health_bridge/health_bridge.dart';
import 'cloud_data_reading_page.dart';

/// 华为 OAuth 页面 - iOS 风格
class HuaweiOAuthTestPageV2 extends StatefulWidget {
  const HuaweiOAuthTestPageV2({super.key});

  @override
  State<HuaweiOAuthTestPageV2> createState() => _HuaweiOAuthTestPageV2State();
}

class _HuaweiOAuthTestPageV2State extends State<HuaweiOAuthTestPageV2> {
  late final HuaweiOAuthHelper _oauthHelper;
  HuaweiOAuthResult? _oauthResult;
  bool _isLoading = false;
  PrivacyAuthStatus? _privacyStatus;
  UserConsentInfo? _consentInfo;
  bool _isCheckingAuth = false;

  @override
  void initState() {
    super.initState();
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
  }

  Future<void> _startAuthorization() async {
    setState(() => _isLoading = true);

    try {
      final authUrl = _oauthHelper.generateAuthUrl();
      if (!mounted) return;

      final result = await Navigator.of(context).push<HuaweiOAuthResult>(
        CupertinoPageRoute(
          builder: (context) => _OAuthWebViewPage(
            authUrl: authUrl,
            oauthHelper: _oauthHelper,
          ),
        ),
      );

      if (!mounted) return;

      if (result != null && result.isSuccess) {
        setState(() {
          _oauthResult = result;
          _isLoading = false;
        });

        _showSuccess('授权成功');
      } else if (result != null && result.hasError) {
        setState(() => _isLoading = false);
        _showError('授权失败: ${result.error}');
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('授权异常: $e');
    }
  }

  Future<void> _checkPrivacyStatus() async {
    if (_oauthResult?.accessToken == null) {
      _showError('请先完成授权');
      return;
    }

    setState(() => _isCheckingAuth = true);

    try {
      final client = HuaweiCloudClient(
        accessToken: _oauthResult!.accessToken!,
        clientId: _oauthHelper.config.clientId,
      );

      final status = await client.checkPrivacyAuthStatus();

      setState(() {
        _privacyStatus = status;
        _isCheckingAuth = false;
      });

      _showSuccess('隐私状态: ${status.description}');
    } catch (e) {
      setState(() => _isCheckingAuth = false);
      _showError('查询失败: $e');
    }
  }

  Future<void> _getUserConsents() async {
    if (_oauthResult?.accessToken == null) {
      _showError('请先完成授权');
      return;
    }

    setState(() => _isCheckingAuth = true);

    try {
      final client = HuaweiCloudClient(
        accessToken: _oauthResult!.accessToken!,
        clientId: _oauthHelper.config.clientId,
      );

      final consentInfo = await client.getUserConsents(
        appId: _oauthHelper.config.clientId,
        lang: 'zh-cn',
      );

      setState(() {
        _consentInfo = consentInfo;
        _isCheckingAuth = false;
      });

      _showSuccess('已授权 ${consentInfo.scopeCount} 个权限');
    } catch (e) {
      setState(() => _isCheckingAuth = false);
      _showError('查询失败: $e');
    }
  }

  Future<void> _revokeConsent() async {
    if (_oauthResult?.accessToken == null) {
      _showError('请先完成授权');
      return;
    }

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('确认取消授权'),
        content: const Text('取消授权后，将无法访问健康数据。\n数据将在3天后自动删除。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCheckingAuth = true);

    try {
      final client = HuaweiCloudClient(
        accessToken: _oauthResult!.accessToken!,
        clientId: _oauthHelper.config.clientId,
      );

      final success = await client.revokeConsent(
        appId: _oauthHelper.config.clientId,
        deleteDataImmediately: false,
      );

      setState(() => _isCheckingAuth = false);

      if (success) {
        _showSuccess('授权已取消');
        setState(() {
          _oauthResult = null;
          _privacyStatus = null;
          _consentInfo = null;
        });
      } else {
        _showError('取消授权失败');
      }
    } catch (e) {
      setState(() => _isCheckingAuth = false);
      _showError('操作失败: $e');
    }
  }

  void _clearToken() {
    setState(() {
      _oauthResult = null;
      _privacyStatus = null;
      _consentInfo = null;
    });
    _showSuccess('Token 已清除');
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
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
    return Material(
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('华为账号授权'),
          backgroundColor: CupertinoColors.systemBackground,
          trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: CupertinoColors.systemPurple.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            '云侧',
            style: TextStyle(
              fontSize: 11,
              color: CupertinoColors.systemPurple,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: _isLoading || _isCheckingAuth
            ? const Center(child: CupertinoActivityIndicator(radius: 14))
            : CustomScrollView(
                slivers: [
                  // 说明信息
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.cloud,
                            size: 60,
                            color: CupertinoColors.systemPurple,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '华为健康云端数据',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '通过华为账号授权，读取云端健康数据',
                            style: TextStyle(
                              fontSize: 15,
                              color: CupertinoColors.secondaryLabel,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 授权按钮
                  if (_oauthResult == null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: CupertinoButton.filled(
                          onPressed: _startAuthorization,
                          child: const Text('开始授权'),
                        ),
                      ),
                    ),

                  // 授权成功后的操作
                  if (_oauthResult != null) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: CupertinoListSection.insetGrouped(
                          header: const Text('Token 信息'),
                          children: [
                            CupertinoListTile(
                              title: const Text('Access Token'),
                              subtitle: Text(
                                '${_oauthResult!.accessToken!.substring(0, 20)}...',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              trailing: const CupertinoListTileChevron(),
                              onTap: () {
                                // 可以显示完整token
                              },
                            ),
                            if (_oauthResult!.refreshToken != null)
                              CupertinoListTile(
                                title: const Text('Refresh Token'),
                                subtitle: Text(
                                  '${_oauthResult!.refreshToken!.substring(0, 20)}...',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            CupertinoListTile(
                              title: const Text('过期时间'),
                              trailing: Text(
                                '${_oauthResult!.expiresIn} 秒',
                                style: const TextStyle(
                                  color: CupertinoColors.secondaryLabel,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 操作按钮
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: CupertinoListSection.insetGrouped(
                          header: const Text('操作'),
                          children: [
                            CupertinoListTile(
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemBlue.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  CupertinoIcons.cloud_download,
                                  color: CupertinoColors.systemBlue,
                                  size: 24,
                                ),
                              ),
                              title: const Text('读取云端数据'),
                              trailing: const CupertinoListTileChevron(),
                              onTap: () {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (context) => CloudDataReadingPage(
                                      accessToken: _oauthResult!.accessToken,
                                      clientId: _oauthHelper.config.clientId,
                                    ),
                                  ),
                                );
                              },
                            ),
                            CupertinoListTile(
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  CupertinoIcons.shield_fill,
                                  color: CupertinoColors.systemGreen,
                                  size: 24,
                                ),
                              ),
                              title: const Text('检查隐私状态'),
                              trailing: const CupertinoListTileChevron(),
                              onTap: _checkPrivacyStatus,
                            ),
                            CupertinoListTile(
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemOrange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  CupertinoIcons.list_bullet,
                                  color: CupertinoColors.systemOrange,
                                  size: 24,
                                ),
                              ),
                              title: const Text('查询授权权限'),
                              trailing: const CupertinoListTileChevron(),
                              onTap: _getUserConsents,
                            ),
                            CupertinoListTile(
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemRed.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  CupertinoIcons.xmark_circle_fill,
                                  color: CupertinoColors.systemRed,
                                  size: 24,
                                ),
                              ),
                              title: const Text('取消授权'),
                              trailing: const CupertinoListTileChevron(),
                              onTap: _revokeConsent,
                            ),
                            CupertinoListTile(
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemGrey.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  CupertinoIcons.trash,
                                  color: CupertinoColors.systemGrey,
                                  size: 24,
                                ),
                              ),
                              title: const Text('清除 Token'),
                              trailing: const CupertinoListTileChevron(),
                              onTap: _clearToken,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 隐私状态
                    if (_privacyStatus != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: CupertinoListSection.insetGrouped(
                            header: const Text('隐私授权状态'),
                            children: [
                              CupertinoListTile(
                                title: const Text('状态'),
                                trailing: Text(
                                  _privacyStatus!.description,
                                  style: TextStyle(
                                    color: _privacyStatus!.isAuthorized
                                        ? CupertinoColors.systemGreen
                                        : CupertinoColors.systemRed,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 用户授权信息
                    if (_consentInfo != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: CupertinoListSection.insetGrouped(
                            header: const Text('授权信息'),
                            children: [
                              CupertinoListTile(
                                title: const Text('应用名称'),
                                trailing: Text(
                                  _consentInfo!.appName,
                                  style: const TextStyle(
                                    color: CupertinoColors.secondaryLabel,
                                  ),
                                ),
                              ),
                              CupertinoListTile(
                                title: const Text('权限数量'),
                                trailing: Text(
                                  '${_consentInfo!.scopeCount} 个',
                                  style: const TextStyle(
                                    color: CupertinoColors.secondaryLabel,
                                  ),
                                ),
                              ),
                              ..._consentInfo!.scopeDescriptions.entries.map(
                                (entry) => CupertinoListTile(
                                  title: Text(
                                    entry.value,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  subtitle: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
        ),
      ),
    );
  }
}

/// WebView 授权页面
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
      ..setBackgroundColor(CupertinoColors.white)
      ..setUserAgent('HealthBridge/1.0 Flutter')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (widget.oauthHelper.isCallbackUrl(url)) {
              _handleCallback(url);
            }
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
          },
          onProgress: (progress) {
            setState(() => _loadingProgress = progress);
          },
          onWebResourceError: (error) {
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (widget.oauthHelper.isCallbackUrl(url)) {
              final uri = Uri.parse(url);
              if (uri.queryParameters.containsKey('code') ||
                  uri.queryParameters.containsKey('error')) {
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

  Future<void> _handleCallback(String callbackUrl) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final params = widget.oauthHelper.parseCallback(callbackUrl);

      if (params == null) {
        if (!mounted) return;
        Navigator.of(context).pop(
          HuaweiOAuthResult(
            error: 'parse_error',
            errorDescription: '解析回调失败',
          ),
        );
        return;
      }

      if (params['error'] != null) {
        if (!mounted) return;
        Navigator.of(context).pop(
          HuaweiOAuthResult(
            error: params['error']!,
            errorDescription: params['error_description'] ?? '未知错误',
          ),
        );
        return;
      }

      final code = params['code'];
      if (code == null) {
        if (!mounted) return;
        Navigator.of(context).pop(
          HuaweiOAuthResult(
            error: 'no_code',
            errorDescription: '未获取到授权码',
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final result = await widget.oauthHelper.exchangeToken(code);
        if (!mounted) return;
        Navigator.of(context).pop(result);
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop(
          HuaweiOAuthResult(
            error: 'exchange_error',
            errorDescription: 'Token 交换失败: $e',
          ),
        );
      }
    } catch (e) {
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
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('华为账号授权'),
        backgroundColor: CupertinoColors.systemBackground,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_isLoading && _loadingProgress > 0)
              SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  value: _loadingProgress / 100,
                  backgroundColor: CupertinoColors.systemGrey5,
                  valueColor: const AlwaysStoppedAnimation(
                    CupertinoColors.systemPurple,
                  ),
                ),
              ),
            if (_isProcessing)
              Container(
                color: CupertinoColors.systemPurple.withOpacity(0.1),
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoActivityIndicator(radius: 10),
                    const SizedBox(width: 12),
                    const Text(
                      '正在换取 Token...',
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.systemPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: WebViewWidget(controller: _webController),
            ),
          ],
        ),
      ),
    );
  }
}
