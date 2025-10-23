import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';

/** 
 * HealthBridgePlugin - 空实现
 * 所有功能在Dart层实现（云侧API）
 */
export default class HealthBridgePlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
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
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    // 所有方法都在Dart层实现，原生层不处理任何逻辑
    result.notImplemented();
  }

  // 发送OAuth结果给Flutter
  sendOAuthResult(result: Record<string, string>): void {
    if (this.channel) {
      this.channel.invokeMethod('onOAuthResult', result);
    }
  }
}
