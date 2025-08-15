package com.health.bridge.health_bridge

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import androidx.annotation.NonNull
import kotlinx.coroutines.*
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.*
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

// Samsung Health SDK imports - 基于官方Samsung Health Data SDK v1.0.0的标准导入
import com.samsung.android.sdk.health.data.HealthDataService
import com.samsung.android.sdk.health.data.HealthDataStore
// data相关导入
import com.samsung.android.sdk.health.data.data.AggregatedData
// 权限相关导入
import com.samsung.android.sdk.health.data.permission.Permission
import com.samsung.android.sdk.health.data.permission.AccessType
// Samsung Health SDK 请求相关导入
import com.samsung.android.sdk.health.data.request.ReadDataRequest
import com.samsung.android.sdk.health.data.request.AggregateRequest
import com.samsung.android.sdk.health.data.request.LocalDateFilter
import com.samsung.android.sdk.health.data.request.DataTypes
import com.samsung.android.sdk.health.data.request.DataType
import com.samsung.android.sdk.health.data.request.LocalTimeFilter
import com.samsung.android.sdk.health.data.request.Ordering
import com.samsung.android.sdk.health.data.request.LocalTimeGroup
import com.samsung.android.sdk.health.data.request.LocalTimeGroupUnit
// Samsung Health SDK 数据相关导入  
import com.samsung.android.sdk.health.data.data.HealthDataPoint
import com.samsung.android.sdk.health.data.data.AggregateOperation
// response 相关导入
import com.samsung.android.sdk.health.data.response.DataResponse

/** HealthBridgePlugin */
class HealthBridgePlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private val coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    // Samsung Health related variables
    private var healthDataStore: HealthDataStore? = null
    private var isInitialized = false
    private var isSamsungHealthAvailable = false
    private var hasPermissions = false
    
    companion object {
        private const val TAG = "HealthBridgePlugin"
        private const val SAMSUNG_HEALTH_PACKAGE = "com.sec.android.app.shealth"
        private const val MIN_SAMSUNG_HEALTH_VERSION = 6300000 // Samsung Health 6.30+
        
        // SDK版本信息
        private const val IMPLEMENTATION_VERSION = "5.0"
        private const val SDK_BASED_IMPLEMENTATION = true
    }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "health_bridge")
    channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        initializeSamsungHealth()
    }
    
    private fun initializeSamsungHealth() {
        try {
            Log.d(TAG, "🚀 开始初始化Samsung Health SDK (v$IMPLEMENTATION_VERSION)")
            Log.d(TAG, "📱 环境信息:")
            Log.d(TAG, "   - Context: ${context.javaClass.simpleName}")
            Log.d(TAG, "   - Package: ${context.packageName}")
            
            // 检查Samsung Health应用可用性
            val isAvailable = checkSamsungHealthAvailability()
            if (isAvailable) {
                // 初始化HealthDataStore
                healthDataStore = HealthDataService.getStore(context)
                isSamsungHealthAvailable = true
                Log.d(TAG, "✅ Samsung Health SDK初始化成功")
                Log.d(TAG, "   - Store类型: ${healthDataStore?.javaClass?.simpleName}")
                Log.d(TAG, "   - Store实例: ${healthDataStore?.hashCode()}")
            } else {
                Log.w(TAG, "⚠️ Samsung Health应用不可用")
                isSamsungHealthAvailable = false
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Samsung Health初始化失败: ${e.message}", e)
            healthDataStore = null
            isSamsungHealthAvailable = false
        }
    }
    
    /**
     * 检查Samsung Health应用可用性
     */
    private fun checkSamsungHealthAvailability(): Boolean {
        return try {
            val packageManager = context.packageManager
            
            // 检查Samsung Health应用是否已安装
            val packageInfo = try {
                packageManager.getPackageInfo(SAMSUNG_HEALTH_PACKAGE, 0)
            } catch (e: PackageManager.NameNotFoundException) {
                Log.w(TAG, "Samsung Health应用未安装")
                return false
            }
            
            // 检查版本兼容性
            val versionCode = packageInfo.longVersionCode
            Log.d(TAG, "检测到Samsung Health版本: $versionCode")
            
            if (versionCode < MIN_SAMSUNG_HEALTH_VERSION) {
                Log.w(TAG, "Samsung Health版本较低: $versionCode, 最低要求: $MIN_SAMSUNG_HEALTH_VERSION")
                return false
            }
            
            Log.d(TAG, "✅ Samsung Health应用验证通过: version $versionCode")
            true
            
        } catch (e: Exception) {
            Log.e(TAG, "检查Samsung Health可用性失败", e)
            false
        }
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "getAvailableHealthPlatforms" -> {
                getAvailableHealthPlatforms(result)
            }
            "initializeHealthPlatform" -> {
                initializeHealthPlatform(call, result)
            }

            "readStepCount" -> {
                readStepCount(call, result)
            }
            "readStepCountForDateRange" -> {
                readStepCountForDateRange(call, result)
            }
            "readStepCountForDate" -> {
                readStepCountForDate(call, result)
            }
            "disconnect" -> {
                disconnect(result)
            }
            else -> {
      result.notImplemented()
            }
        }
    }

    // 获取可用的健康平台列表
    private fun getAvailableHealthPlatforms(result: Result) {
        try {
            val availablePlatforms = mutableListOf<String>()
            
            // 检查Samsung Health是否可用
            if (isSamsungHealthAvailable && healthDataStore != null) {
                Log.d(TAG, "✅ Samsung Health可用 - SDK已连接")
                availablePlatforms.add("samsung_health")
            } else {
                Log.d(TAG, "❌ Samsung Health不可用")
                Log.d(TAG, "   - isSamsungHealthAvailable: $isSamsungHealthAvailable")
                Log.d(TAG, "   - healthDataStore != null: ${healthDataStore != null}")
            }
            
            // TODO: 检查其他健康平台 (Google Fit, Apple Health, Huawei Health等)
            
            Log.d(TAG, "可用平台列表: $availablePlatforms")
            result.success(availablePlatforms)
        } catch (e: Exception) {
            Log.e(TAG, "获取可用健康平台失败: ${e.message}", e)
            result.success(emptyList<String>())
        }
    }

    // 初始化指定的健康平台
    private fun initializeHealthPlatform(call: MethodCall, result: Result) {
        val platform = call.argument<String>("platform") ?: "samsung_health"
        
        coroutineScope.launch {
            try {
                when (platform) {
                    "samsung_health" -> {
                        if (healthDataStore == null) {
                            result.success(mapOf(
                                "status" to "platform_not_supported",
                                "platform" to platform,
                                "message" to "Samsung Health not available"
                            ))
                            return@launch
                        }
                        
                        if (activity == null) {
                            result.success(mapOf(
                                "status" to "error",
                                "platform" to platform,
                                "message" to "Activity not available for permission request"
                            ))
                            return@launch
                        }
                        
                        Log.d(TAG, "🚀 开始Samsung Health平台初始化...")
                        Log.d(TAG, "📊 当前状态:")
                        Log.d(TAG, "   - isSamsungHealthAvailable: $isSamsungHealthAvailable")
                        Log.d(TAG, "   - healthDataStore != null: ${healthDataStore != null}")
                        Log.d(TAG, "   - activity != null: ${activity != null}")
                        
                        // 请求权限
                        val permissionResult = checkAndRequestPermissions(activity!!)
                        
                        if (permissionResult) {
                            isInitialized = true
                            Log.d(TAG, "✅ Samsung Health平台初始化成功")
                            
                            result.success(mapOf(
                                "status" to "connected",
                                "platform" to platform,
                                "message" to "Samsung Health initialized successfully",
                                "hasPermissions" to hasPermissions,
                                "permissionNote" to if (hasPermissions) "权限已授予" else "需要手动在Samsung Health中授权",
                                "isRealData" to true,
                                "dataSource" to "samsung_health_sdk_v5",
                                "version" to IMPLEMENTATION_VERSION,
                                "appCheckStatus" to "verified",
                                "sdkStatus" to "official_sdk",
                                "apiVersion" to "data_sdk_1.0.0",
                                "permissionsGranted" to hasPermissions,
                                "note" to "Samsung Health Data SDK integration complete"
                            ))
                        } else {
                            Log.w(TAG, "⚠️ Samsung Health权限请求失败")
                            
                            result.success(mapOf(
                                "status" to "permission_denied",
                                "platform" to platform,
                                "message" to "Permission request failed or denied",
                                "hasPermissions" to false,
                                "permissionNote" to "请手动在Samsung Health应用中授权",
                                "troubleshooting" to mapOf(
                                    "step1" to "打开Samsung Health应用",
                                    "step2" to "进入设置 > 数据权限",
                                    "step3" to "找到您的应用并授予数据访问权限"
                                )
                            ))
                        }
                    }
                    else -> {
                        result.success(mapOf(
                            "status" to "platform_not_supported",
                            "platform" to platform,
                            "message" to "Platform $platform not supported"
                        ))
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "初始化健康平台失败: ${e.message}", e)
                result.success(mapOf(
                    "status" to "error",
                    "platform" to platform,
                    "message" to e.message
                ))
            }
        }
    }




    // 读取当天步数
    private fun readStepCount(call: MethodCall, result: Result) {
        val platform = call.argument<String>("platform") ?: "samsung_health"
        
        coroutineScope.launch {
            try {
                when (platform) {
                    "samsung_health" -> {
                        Log.d(TAG, "🚀 开始读取Samsung Health步数数据...")
                        
                        // 使用真实的Samsung Health SDK API
                        val stepData = readTodayStepCount()
                        
                        if (stepData != null) {
                            val totalSteps = (stepData["steps"] as Long).toInt()
                            
                            Log.d(TAG, "✅ 步数读取成功: $totalSteps 步")
                            
                            // 构造返回数据，符合Flutter侧期望的格式
                            val responseData = listOf(
                                mapOf(
                                    "type" to "steps",
                                    "value" to totalSteps.toDouble(),
                                    "timestamp" to stepData["timestamp"],
                                    "unit" to "steps",
                                    "platform" to platform
                                )
                            )

                            result.success(mapOf(
                                "status" to "success",
                                "platform" to platform,
                                "data" to responseData,
                                "totalSteps" to totalSteps,
                                "count" to responseData.size,
                                "isRealData" to stepData["isRealData"],
                                "dataSource" to stepData["dataSource"],
                                "debug" to stepData["debug"]
                            ))
                        } else {
                            Log.e(TAG, "❌ 步数读取失败")
                            
                            result.success(mapOf(
                                "status" to "error",
                                "platform" to platform,
                                "message" to "Failed to read step count from Samsung Health",
                                "errorType" to "samsung_health_error"
                            ))
                        }
                    }
                    else -> {
                        result.success(mapOf(
                            "status" to "platform_not_supported",
                            "platform" to platform,
                            "message" to "Platform $platform not supported"
                        ))
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ 步数读取异常: ${e.message}", e)
                result.success(mapOf(
                    "status" to "error",
                    "platform" to platform,
                    "message" to e.message,
                    "errorType" to "unexpected_error"
                ))
            }
        }
    }

    // 读取指定日期的步数
    private fun readStepCountForDate(call: MethodCall, result: Result) {
        val dateMillis = call.argument<Long>("date") ?: System.currentTimeMillis()
        val platform = call.argument<String>("platform") ?: "samsung_health"
        
        coroutineScope.launch {
            try {
                when (platform) {
                    "samsung_health" -> {
                        Log.d(TAG, "🚀 开始读取Samsung Health指定日期步数数据...")
                        
                        // 将时间戳转换为LocalDate
                        val targetDate = Instant.ofEpochMilli(dateMillis)
                            .atZone(ZoneId.systemDefault())
                            .toLocalDate()
                        
                        Log.d(TAG, "   - 目标日期: $targetDate")
                        
                        // 使用真实的Samsung Health SDK API
                        val stepData = readStepCountForSpecificDate(targetDate)
                        
                        if (stepData != null) {
                            val totalSteps = (stepData["steps"] as Long).toInt()
                            
                            Log.d(TAG, "✅ 指定日期步数读取成功: $totalSteps 步")
                            
                            // 构造返回数据，符合Flutter侧期望的格式
                            val responseData = listOf(
                                mapOf(
                                    "type" to "steps",
                                    "value" to totalSteps.toDouble(),
                                    "timestamp" to dateMillis,
                                    "unit" to "steps",
                                    "platform" to platform,
                                    "date" to targetDate.toString()
                                )
                            )

                            result.success(mapOf(
                                "status" to "success",
                                "platform" to platform,
                                "data" to responseData,
                                "totalSteps" to totalSteps,
                                "count" to responseData.size,
                                "date" to targetDate.toString(),
                                "isRealData" to stepData["isRealData"],
                                "dataSource" to stepData["dataSource"]
                            ))
                        } else {
                            Log.e(TAG, "❌ 指定日期步数读取失败")
                            
                            result.success(mapOf(
                                "status" to "error",
                                "platform" to platform,
                                "message" to "Failed to read step count for date: $targetDate",
                                "errorType" to "samsung_health_error"
                            ))
                        }
                    }
                    else -> {
                        result.success(mapOf(
                            "status" to "platform_not_supported",
                            "platform" to platform,
                            "message" to "Platform $platform not supported"
                        ))
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ 读取指定日期步数异常: ${e.message}", e)
                result.success(mapOf(
                    "status" to "error",
                    "platform" to platform,
                    "message" to e.message,
                    "errorType" to "unexpected_error"
                ))
            }
        }
    }

    // 读取指定日期范围的步数
    private fun readStepCountForDateRange(call: MethodCall, result: Result) {
        val startDate = call.argument<Long>("startDate") ?: System.currentTimeMillis()
        val endDate = call.argument<Long>("endDate") ?: System.currentTimeMillis()
        val platform = call.argument<String>("platform") ?: "samsung_health"
        
        when (platform) {
            "samsung_health" -> {
                // 模拟返回范围步数数据
                val mockStepsData = listOf(
                    mapOf(
                        "type" to "steps",
                        "value" to 5000.0,
                        "timestamp" to startDate,
                        "unit" to "steps",
                        "platform" to platform
                    ),
                    mapOf(
                        "type" to "steps",
                        "value" to 6500.0,
                        "timestamp" to (startDate + 86400000), // 1天后
                        "unit" to "steps",
                        "platform" to platform
                    ),
                    mapOf(
                        "type" to "steps",
                        "value" to 4200.0,
                        "timestamp" to (startDate + 172800000), // 2天后
                        "unit" to "steps",
                        "platform" to platform
                    )
                )
                val totalSteps = 15700

                result.success(mapOf(
                    "status" to "success",
                    "platform" to platform,
                    "data" to mockStepsData,
                    "totalSteps" to totalSteps,
                    "count" to mockStepsData.size
                ))
            }
            else -> {
                result.success(mapOf(
                    "status" to "platform_not_supported",
                    "platform" to platform,
                    "message" to "Platform $platform not supported"
                ))
            }
        }
    }

    // 断开连接
    private fun disconnect(result: Result) {
        try {
            // 清理资源
            result.success(null)
        } catch (e: Exception) {
            result.success(null)
        }
    }
    
    /**
     * 检查和请求权限 - 基于用户提供的完整实现
     */
    private suspend fun checkAndRequestPermissions(activity: Activity): Boolean = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "🔐 开始检查和请求Samsung Health权限...")
            
            if (healthDataStore == null) {
                Log.e(TAG, "❌ HealthDataStore为null，无法进行权限检查")
                return@withContext false
            }
            
            // 创建所需权限集合
            val requiredPermissions = setOf(
                Permission.of(DataTypes.STEPS, AccessType.READ)
            )
            
            Log.d(TAG, "📋 检查当前权限状态...")
            Log.d(TAG, "   - 必需权限数量: ${requiredPermissions.size}")
            
            // 检查当前已授予的权限
            val grantedPermissions = healthDataStore!!.getGrantedPermissions(requiredPermissions)
            Log.d(TAG, "📊 当前已授予权限数量: ${grantedPermissions.size}/${requiredPermissions.size}")
            
            if (grantedPermissions.containsAll(requiredPermissions)) {
                Log.d(TAG, "✅ 所有必需权限已授予")
                hasPermissions = true
                return@withContext true
            }
            
            // 申请缺失的权限
            Log.d(TAG, "🚨 发现缺失权限，开始申请...")
            val missingPermissions = requiredPermissions - grantedPermissions
            Log.d(TAG, "   - 缺失权限数量: ${missingPermissions.size}")
            
            // 申请权限 - 会弹出Samsung Health权限对话框
            Log.d(TAG, "📱 发起权限申请对话框...")
            healthDataStore!!.requestPermissions(requiredPermissions, activity)
            
            // 等待用户操作后重新检查权限
            Log.d(TAG, "⏳ 等待用户授权操作...")
            delay(1500) // 给用户足够时间操作
            
            val finalPermissions = healthDataStore!!.getGrantedPermissions(requiredPermissions)
            val allGranted = finalPermissions.containsAll(requiredPermissions)
            
            Log.d(TAG, "📈 权限申请后检查: ${finalPermissions.size}/${requiredPermissions.size}")
            Log.d(TAG, if (allGranted) "✅ 权限申请成功" else "⚠️ 权限申请被拒绝或部分授予")
            
            hasPermissions = allGranted
            return@withContext allGranted
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ 权限检查/申请失败: ${e.message}", e)
            hasPermissions = false
            return@withContext false
        }
    }

    /**
     * 获取聚合步数结果 - 基于用户提供的实现
     */
    private fun getAggregateResult(
        store: HealthDataStore,
        date: LocalDate
    ): DataResponse<AggregatedData<Long>> {

        val stepsRequest =
            DataType.StepsType.TOTAL.requestBuilder.setLocalTimeFilterWithGroup(
                LocalTimeFilter.of(date.atStartOfDay(), date.plusDays(1).atStartOfDay()),
                LocalTimeGroup.of(LocalTimeGroupUnit.MINUTELY, 30)
            ).build()

        // An asynchronous API call for an aggregate request.
        return store.aggregateDataAsync(stepsRequest).get()
    }
    
    /**
     * 读取指定日期步数 - 使用真实Samsung Health SDK API
     */
    private suspend fun readStepCountForSpecificDate(date: LocalDate): Map<String, Any>? = withContext(Dispatchers.IO) {
        try {
            if (!isInitialized || !isSamsungHealthAvailable) {
                Log.e(TAG, "Samsung Health not initialized")
                return@withContext null
            }
            
            if (!hasPermissions) {
                Log.e(TAG, "Required permissions not granted")
                return@withContext null
            }
            
            if (healthDataStore == null) {
                Log.e(TAG, "HealthDataStore not initialized")
                return@withContext null
            }
            
            Log.d(TAG, "📊 开始读取指定日期步数...")
            Log.d(TAG, "   - 目标日期: $date")
            
            val stepsResponse = getAggregateResult(healthDataStore!!, date)
            var totalSteps = 0L
            
            stepsResponse.dataList.forEach {
                val steps = it.value ?: 0L
                totalSteps += steps
                Log.i(TAG, "step count segment for $date: $steps")
            }
            
            Log.d(TAG, "✅ 指定日期($date)步数读取成功: $totalSteps 步")
            
            // 构造返回数据
            val stepData = mapOf(
                "steps" to totalSteps,
                "date" to date.toString(),
                "platform" to "samsung_health",
                "dataSource" to "samsung_health_sdk_official",
                "timestamp" to System.currentTimeMillis(),
                "isRealData" to true, // 真实数据
                "debug" to mapOf(
                    "permissionStatus" to "granted",
                    "connectionStatus" to "connected",
                    "healthDataStoreClass" to (healthDataStore?.javaClass?.simpleName ?: "null"),
                    "segmentCount" to stepsResponse.dataList.size,
                    "sdkInitialized" to isInitialized,
                    "permissionsGranted" to hasPermissions,
                    "targetDate" to date.toString()
                ),
                "apiStatus" to "official_samsung_health_sdk",
                "note" to "Real Samsung Health SDK data for date: $date"
            )
            
            return@withContext stepData
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ 读取指定日期($date)步数失败: ${e.message}", e)
            return@withContext null
        }
    }
    
    /**
     * 读取今日步数 - 使用真实Samsung Health SDK API
     */
    private suspend fun readTodayStepCount(): Map<String, Any>? {
        return readStepCountForSpecificDate(LocalDate.now())
    }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
        coroutineScope.cancel()
    }

    // ActivityAware interface methods
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}