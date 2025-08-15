import Flutter
import UIKit

// MARK: - Constants
private struct PluginConstants {
    static let channelName = "health_bridge"
    static let appleHealthPlatform = "apple_health"
    
    struct Methods {
        static let getPlatformVersion = "getPlatformVersion"
        static let getAvailableHealthPlatforms = "getAvailableHealthPlatforms"
        static let initializeHealthPlatform = "initializeHealthPlatform"
        static let insertGlucoseData = "insertGlucoseData"
        static let readDailyGlucoseData = "readDailyGlucoseData"
        static let readStepCount = "readStepCount"
        static let readStepCountForDateRange = "readStepCountForDateRange"
        static let readStepCountForDate = "readStepCountForDate"
        static let disconnect = "disconnect"
    }
    
    struct ErrorCodes {
        static let invalidArguments = "INVALID_ARGUMENTS"
        static let initializationFailed = "INITIALIZATION_FAILED"
        static let unsupportedPlatform = "UNSUPPORTED_PLATFORM"
        static let operationFailed = "OPERATION_FAILED"
    }
}

// MARK: - Response Models
private struct HealthResponse {
    static func success(data: [String: Any] = [:]) -> [String: Any] {
        var response: [String: Any] = ["success": true]
        response.merge(data) { _, new in new }
        return response
    }
    
    static func failure(message: String, platform: String? = nil) -> [String: Any] {
        var response: [String: Any] = [
            "success": false,
            "message": message
        ]
        if let platform = platform {
            response["platform"] = platform
        }
        return response
    }
}

// MARK: - Logger
private struct HealthLogger {
    static func log(_ message: String, level: LogLevel = .info) {
        #if DEBUG
        print("🏥 [HealthPlugin] \(level.emoji) \(message)")
        #endif
    }
    
    static func logError(_ error: Error, context: String) {
        log("❌ Error in \(context): \(error.localizedDescription)", level: .error)
    }
}

private enum LogLevel {
    case info, warning, error
    
    var emoji: String {
        switch self {
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

public class HealthBridgePlugin: NSObject, FlutterPlugin {
    private var appleHealthManager: AppleHealthManager?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: PluginConstants.channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = HealthBridgePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        instance.appleHealthManager = AppleHealthManager()
        HealthLogger.log("Plugin registered successfully")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        HealthLogger.log("Handling method: \(call.method)")
        
        switch call.method {
        case PluginConstants.Methods.getPlatformVersion:
            handleGetPlatformVersion(result: result)
            
        case PluginConstants.Methods.getAvailableHealthPlatforms:
            handleGetAvailableHealthPlatforms(result: result)
            
        case PluginConstants.Methods.initializeHealthPlatform:
            handleInitializeHealthPlatform(call: call, result: result)
            
        case PluginConstants.Methods.insertGlucoseData:
            handleInsertGlucoseData(call: call, result: result)
            
        case PluginConstants.Methods.readDailyGlucoseData:
            handleReadDailyGlucoseData(call: call, result: result)
            
        case PluginConstants.Methods.readStepCount:
            handleReadStepCount(call: call, result: result)
            
        case PluginConstants.Methods.readStepCountForDateRange:
            handleReadStepCountForDateRange(call: call, result: result)
            
        case PluginConstants.Methods.readStepCountForDate:
            handleReadStepCountForDate(call: call, result: result)
            
        case PluginConstants.Methods.disconnect:
            handleDisconnect(result: result)
            
        default:
            HealthLogger.log("Method not implemented: \(call.method)", level: .warning)
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - Method Handlers
private extension HealthBridgePlugin {
    
    func handleGetPlatformVersion(result: @escaping FlutterResult) {
        let version = "iOS " + UIDevice.current.systemVersion
        HealthLogger.log("Platform version: \(version)")
        result(version)
    }
    
    func handleGetAvailableHealthPlatforms(result: @escaping FlutterResult) {
        let platforms = [PluginConstants.appleHealthPlatform]
        HealthLogger.log("Available platforms: \(platforms)")
        result(platforms)
    }
    
    func handleInitializeHealthPlatform(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let platform = extractPlatform(from: call.arguments, result: result) else { return }
        
        guard platform == PluginConstants.appleHealthPlatform else {
            HealthLogger.log("Unsupported platform: \(platform)", level: .warning)
            result(createUnsupportedPlatformError(platform: platform))
            return
        }
        
        HealthLogger.log("Initializing Apple Health...")
        appleHealthManager?.initialize { [weak self] success, error in
            if success {
                HealthLogger.log("Apple Health initialized successfully")
                let response = HealthResponse.success(data: [
                    "status": "connected",
                    "hasPermissions": true,
                    "platform": PluginConstants.appleHealthPlatform
                ])
                result(response)
            } else {
                HealthLogger.log("Apple Health initialization failed: \(error ?? "Unknown error")", level: .error)
                result(self?.createInitializationError(error: error))
            }
        }
    }
    
    func handleInsertGlucoseData(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let platform = extractPlatform(from: arguments, result: result),
              let timestamp = arguments["timestamp"] as? Double,
              let value = arguments["value"] as? Double else { return }
        
        guard platform == PluginConstants.appleHealthPlatform else {
            result(HealthResponse.failure(message: "Platform \(platform) is not supported", platform: platform))
            return
        }
        
        let date = Date(timeIntervalSince1970: timestamp / 1000.0)
        HealthLogger.log("Inserting glucose data: \(value) at \(date)")
        
        appleHealthManager?.insertGlucoseData(value: value, date: date) { success, error in
            if success {
                HealthLogger.log("Glucose data inserted successfully")
                let response = HealthResponse.success(data: [
                    "message": "Blood glucose data inserted successfully",
                    "platform": PluginConstants.appleHealthPlatform,
                    "data": [
                        "type": "glucose",
                        "value": value,
                        "timestamp": Int64(timestamp),
                        "unit": "mmol/L"
                    ]
                ])
                result(response)
            } else {
                HealthLogger.log("Failed to insert glucose data: \(error ?? "Unknown error")", level: .error)
                let message = error ?? "Failed to insert glucose data"
                result(HealthResponse.failure(message: message, platform: PluginConstants.appleHealthPlatform))
            }
        }
    }
    
    func handleReadDailyGlucoseData(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let platform = extractPlatform(from: arguments, result: result),
              let startTime = arguments["startTime"] as? Double else { return }
        
        guard platform == PluginConstants.appleHealthPlatform else {
            result(HealthResponse.failure(message: "Platform \(platform) is not supported", platform: platform))
            return
        }
        
        let startDate = Date(timeIntervalSince1970: startTime / 1000.0)
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? Date()
        
        HealthLogger.log("Reading glucose data from \(startDate) to \(endDate)")
        
        appleHealthManager?.readGlucoseData(from: startDate, to: endDate) { glucoseData, error in
            if let error = error {
                HealthLogger.log("Failed to read glucose data: \(error)", level: .error)
                result(HealthResponse.failure(message: error, platform: PluginConstants.appleHealthPlatform))
            } else {
                let dataList = glucoseData.map { data in
                    [
                        "type": "glucose",
                        "value": data["value"] as? Double ?? 0.0,
                        "timestamp": data["timestamp"] as? Int64 ?? 0,
                        "unit": "mmol/L",
                        "platform": PluginConstants.appleHealthPlatform
                    ]
                }
                
                HealthLogger.log("Successfully read \(dataList.count) glucose records")
                let response = HealthResponse.success(data: [
                    "platform": PluginConstants.appleHealthPlatform,
                    "dataType": "glucose",
                    "data": dataList,
                    "count": dataList.count
                ])
                result(response)
            }
        }
    }
    
    func handleReadStepCount(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let platform = extractPlatform(from: call.arguments, result: result) else { return }
        
        guard platform == PluginConstants.appleHealthPlatform else {
            result(HealthResponse.failure(message: "Platform \(platform) is not supported", platform: platform))
            return
        }
        
        HealthLogger.log("Reading today's step count")
        
        appleHealthManager?.readTodayStepCount { stepData, error in
            if let error = error {
                HealthLogger.log("Failed to read step count: \(error)", level: .error)
                result(HealthResponse.failure(message: error, platform: PluginConstants.appleHealthPlatform))
            } else {
                let totalSteps = stepData["totalSteps"] as? Int ?? 0
                HealthLogger.log("Successfully read step count: \(totalSteps) steps")
                
                let responseData = stepData["data"] as? [[String: Any]] ?? []
                
                let response = HealthResponse.success(data: [
                    "status": "success",
                    "platform": PluginConstants.appleHealthPlatform,
                    "data": responseData,
                    "totalSteps": totalSteps,
                    "count": responseData.count,
                    "totalCalories": stepData["totalCalories"] as? Double ?? 0.0
                ])
                result(response)
            }
        }
    }
    
    func handleReadStepCountForDateRange(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let platform = extractPlatform(from: arguments, result: result),
              let startDate = arguments["startDate"] as? Double,
              let endDate = arguments["endDate"] as? Double else { return }
        
        guard platform == PluginConstants.appleHealthPlatform else {
            result(HealthResponse.failure(message: "Platform \(platform) is not supported", platform: platform))
            return
        }
        
        let startDateTime = Date(timeIntervalSince1970: startDate / 1000.0)
        let endDateTime = Date(timeIntervalSince1970: endDate / 1000.0)
        
        HealthLogger.log("Reading step count for date range: \(startDateTime) to \(endDateTime)")
        
        appleHealthManager?.getStepCount(startDate: startDateTime, endDate: endDateTime) { steps in
            let totalSteps = Int(steps)
            HealthLogger.log("Successfully read step count for date range: \(totalSteps) steps")
            
            let response = HealthResponse.success(data: [
                "platform": PluginConstants.appleHealthPlatform,
                "dataType": "steps",
                "data": [],
                "count": totalSteps,
                "totalSteps": totalSteps
            ])
            result(response)
        }
    }
    
    func handleReadStepCountForDate(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let platform = extractPlatform(from: arguments, result: result),
              let dateMillis = arguments["date"] as? Double else { return }
        
        guard platform == PluginConstants.appleHealthPlatform else {
            result(HealthResponse.failure(message: "Platform \(platform) is not supported", platform: platform))
            return
        }
        
        let targetDate = Date(timeIntervalSince1970: dateMillis / 1000.0)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: targetDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        HealthLogger.log("Reading step count for date: \(startOfDay)")
        
        appleHealthManager?.getStepCount(startDate: startOfDay, endDate: endOfDay) { steps in
            let totalSteps = Int(steps)
            HealthLogger.log("Successfully read step count for date: \(totalSteps) steps")
            
            let responseData = [[
                "type": "steps",
                "value": Double(totalSteps),
                "timestamp": Int64(dateMillis),
                "unit": "steps",
                "platform": PluginConstants.appleHealthPlatform
            ]]
            
            let response = HealthResponse.success(data: [
                "status": "success",
                "platform": PluginConstants.appleHealthPlatform,
                "data": responseData,
                "totalSteps": totalSteps,
                "count": responseData.count
            ])
            result(response)
        }
    }
    
    func handleDisconnect(result: @escaping FlutterResult) {
        HealthLogger.log("Disconnecting from Apple Health")
        appleHealthManager?.disconnect()
        result(nil)
    }
}

// MARK: - Helper Methods
private extension HealthBridgePlugin {
    
    func extractPlatform(from arguments: Any?, result: @escaping FlutterResult) -> String? {
        guard let arguments = arguments as? [String: Any],
              let platform = arguments["platform"] as? String else {
            result(createInvalidArgumentsError(message: "Platform argument required"))
            return nil
        }
        return platform
    }
    
    func createInvalidArgumentsError(message: String) -> FlutterError {
        return FlutterError(
            code: PluginConstants.ErrorCodes.invalidArguments,
            message: message,
            details: nil
        )
    }
    
    func createInitializationError(error: String?) -> FlutterError {
        return FlutterError(
            code: PluginConstants.ErrorCodes.initializationFailed,
            message: error ?? "Apple Health initialization failed",
            details: nil
        )
    }
    
    func createUnsupportedPlatformError(platform: String) -> FlutterError {
        return FlutterError(
            code: PluginConstants.ErrorCodes.unsupportedPlatform,
            message: "Platform \(platform) is not supported on iOS",
            details: nil
        )
    }
}