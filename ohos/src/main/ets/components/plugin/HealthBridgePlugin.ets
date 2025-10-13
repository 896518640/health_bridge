import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import deviceInfo from '@ohos.deviceInfo';

/** HealthBridgePlugin **/
export default class HealthBridgePlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;

  constructor() {
  }

  getUniqueClassName(): string {
    return "HealthBridgePlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "health_bridge");
    this.channel.setMethodCallHandler(this)
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
}