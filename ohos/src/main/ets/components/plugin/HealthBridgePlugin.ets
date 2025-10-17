import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import deviceInfo from '@ohos.deviceInfo';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import router from '@ohos.router';

/** HealthBridgePlugin **/
export default class HealthBridgePlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext | null = null;
  private static instance: HealthBridgePlugin | null = null;

  constructor() {
    HealthBridgePlugin.instance = this;
  }

  // 获取插件实例（供其他模块使用）
  static getInstance(): HealthBridgePlugin | null {
    return HealthBridgePlugin.instance;
  }

  getUniqueClassName(): string {
    return "HealthBridgePlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "health_bridge");
    this.channel.setMethodCallHandler(this);
    // 获取 context
    this.context = binding.getApplicationContext() as common.UIAbilityContext;
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case "getPlatformVersion":
        result.success(`HarmonyOS ${deviceInfo.osFullName}`);
        break;

      case "getAvailableHealthPlatforms":
        // 鸿蒙系统支持华为健康
        result.success(["huawei_health"]);
        break;

      case "openBrowser":
        this.openBrowser(call, result);
        break;

      case "showOAuthWebView":
        this.showOAuthWebView(call, result);
        break;

      case "initializeHealthPlatform":
      case "readStepCount":
      case "checkPermissions":
      case "requestPermissions":
      case "revokeAllAuthorizations":
      case "revokeAuthorizations":
      case "getSupportedDataTypes":
      case "isDataTypeSupported":
      case "getPlatformCapabilities":
      case "readHealthData":
      case "writeHealthData":
      case "writeBatchHealthData":
        // TODO: 实现鸿蒙华为健康 Kit 集成
        result.success({
          "status": "error",
          "message": "HarmonyOS health integration coming soon",
          "platform": "huawei_health"
        });
        break;

      case "disconnect":
        result.success(null);
        break;

      default:
        result.notImplemented();
        break;
    }
  }

  // 打开系统浏览器
  private openBrowser(call: MethodCall, result: MethodResult): void {
    const url: string | null = call.argument("url") as string | null;
    if (!url || typeof url !== 'string') {
      result.error("INVALID_ARGUMENT", "URL is required", null);
      return;
    }

    try {
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: url
      };

      if (this.context) {
        this.context.startAbility(want);
        result.success(true);
      } else {
        result.error("NO_CONTEXT", "Context not available", null);
      }
    } catch (error) {
      result.error("OPEN_BROWSER_FAILED", `Failed to open browser: ${error}`, null);
    }
  }

  // 处理深层链接回调（由 EntryAbility 调用）
  handleDeepLink(uri: string): void {
    if (this.channel) {
      this.channel.invokeMethod("onOAuthCallback", uri);
    }
  }

  // 打开 OAuth WebView 页面
  private showOAuthWebView(call: MethodCall, result: MethodResult): void {
    const authUrl: string | null = call.argument("authUrl") as string | null;
    const redirectUri: string | null = call.argument("redirectUri") as string | null;

    if (!authUrl || typeof authUrl !== 'string') {
      result.error("INVALID_ARGUMENT", "authUrl is required", null);
      return;
    }

    if (!redirectUri || typeof redirectUri !== 'string') {
      result.error("INVALID_ARGUMENT", "redirectUri is required", null);
      return;
    }

    console.info('[HealthBridge] 准备打开 OAuth WebView');
    console.info('[HealthBridge] authUrl: ' + authUrl);
    console.info('[HealthBridge] redirectUri: ' + redirectUri);

    try {
      // 使用 router 打开 WebView 页面
      console.info('[HealthBridge] 调用 router.pushUrl');
      console.info('[HealthBridge] URL: pages/HuaweiOAuthWebViewPage');
      console.info('[HealthBridge] Params: ' + JSON.stringify({ authUrl, redirectUri }));
      
      router.pushUrl({
        url: 'pages/HuaweiOAuthWebViewPage',
        params: {
          authUrl: authUrl,
          redirectUri: redirectUri
        }
      })
      .then(() => {
        console.info('[HealthBridge] ✅ WebView 页面打开成功');
        // 注意：这里先返回 success，实际结果会通过 onOAuthResult 回调
        result.success(true);
      })
      .catch((err: Error) => {
        console.error('[HealthBridge] ❌ 打开 WebView 失败: ' + JSON.stringify(err));
        console.error('[HealthBridge] Error message: ' + err.message);
        result.error("OPEN_WEBVIEW_FAILED", `Failed to open WebView: ${err.message}`, null);
      });
    } catch (error) {
      console.error('[HealthBridge] showOAuthWebView 异常: ' + error);
      result.error("OPEN_WEBVIEW_FAILED", `Failed to open WebView: ${error}`, null);
    }
  }

  // 发送 OAuth 结果给 Flutter（由 WebView 页面调用）
  sendOAuthResult(result: Record<string, string>): void {
    if (this.channel) {
      console.info('[HealthBridge] 发送 OAuth 结果: ' + JSON.stringify(result));
      this.channel.invokeMethod("onOAuthResult", result);
    }
  }
}