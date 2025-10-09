package com.health.bridge.health_bridge.providers

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import kotlinx.coroutines.*
import kotlin.coroutines.suspendCoroutine
import kotlin.coroutines.resume
import com.health.bridge.health_bridge.utils.TimeCompat
import java.time.LocalDate
import java.time.ZoneId

// Samsung Health SDK imports
import com.samsung.android.sdk.health.data.HealthDataService
import com.samsung.android.sdk.health.data.HealthDataStore
import com.samsung.android.sdk.health.data.data.AggregatedData
import com.samsung.android.sdk.health.data.permission.Permission
import com.samsung.android.sdk.health.data.permission.AccessType
import com.samsung.android.sdk.health.data.request.DataTypes
import com.samsung.android.sdk.health.data.request.DataType
import com.samsung.android.sdk.health.data.request.LocalTimeFilter
import com.samsung.android.sdk.health.data.request.LocalTimeGroup
import com.samsung.android.sdk.health.data.request.LocalTimeGroupUnit
import com.samsung.android.sdk.health.data.response.DataResponse
import kotlinx.coroutines.delay

/**
 * Samsung Health数据提供者实现
 * 负责Samsung Health SDK的具体集成
 */
class SamsungHealthProvider(
    private val context: Context,
    private var activity: Activity? = null
) : HealthDataProvider {
    
    override val platformKey = "samsung_health"
    
    private var healthDataStore: HealthDataStore? = null
    private var hasPermissions = false
    
    companion object {
        private const val TAG = "SamsungHealthProvider"
        private const val SAMSUNG_HEALTH_PACKAGE = "com.sec.android.app.shealth"
        private const val MIN_VERSION = 6300000L
        private const val MIN_API_LEVEL = 29
    }
    
    override fun isAvailable(): Boolean {
        return try {
            // 首先检查系统API级别
            if (Build.VERSION.SDK_INT < MIN_API_LEVEL) {
                Log.w(TAG, "Samsung Health Data SDK requires API level $MIN_API_LEVEL or higher, current: ${Build.VERSION.SDK_INT}")
                return false
            }
            
            // 然后检查Samsung Health应用是否安装且版本足够
            val packageManager = context.packageManager
            val packageInfo = packageManager.getPackageInfo(SAMSUNG_HEALTH_PACKAGE, 0)
            val versionCheck = packageInfo.longVersionCode >= MIN_VERSION
            
            Log.d(TAG, "Samsung Health availability check - API: ${Build.VERSION.SDK_INT}, Version: ${packageInfo.longVersionCode}, Required: $MIN_VERSION, Available: $versionCheck")
            versionCheck
        } catch (e: PackageManager.NameNotFoundException) {
            Log.w(TAG, "Samsung Health app not found")
            false
        } catch (e: Exception) {
            Log.e(TAG, "Error checking Samsung Health availability", e)
            false
        }
    }
    
    override suspend fun initialize(): Boolean = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "🚀 Starting Samsung Health initialization...")
            Log.d(TAG, "   - Activity: ${if (activity != null) "✅ Available" else "❌ Null"}")
            Log.d(TAG, "   - Context: ${if (context != null) "✅ Available" else "❌ Null"}")

            if (!isAvailable()) {
                Log.w(TAG, "❌ Samsung Health not available on this device")
                return@withContext false
            }

            Log.d(TAG, "✅ Samsung Health is available, getting HealthDataStore...")

            try {
                healthDataStore = HealthDataService.getStore(context)
                Log.d(TAG, "✅ HealthDataStore obtained: ${if (healthDataStore != null) "SUCCESS" else "FAILED"}")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to get HealthDataStore", e)
                return@withContext false
            }

            if (healthDataStore == null) {
                Log.e(TAG, "❌ HealthDataStore is null after getStore()")
                return@withContext false
            }

            // 请求权限
            if (activity != null) {
                Log.d(TAG, "🔐 Activity available, requesting initial permissions...")
                hasPermissions = checkAndRequestPermissions(activity!!)
                Log.d(TAG, "🔐 Permission request result: ${if (hasPermissions) "✅ GRANTED" else "❌ DENIED"}")
            } else {
                Log.w(TAG, "⚠️ Activity is null, skipping initial permission request")
                hasPermissions = false
            }

            Log.d(TAG, "✅ Samsung Health initialized successfully")
            Log.d(TAG, "   - HealthDataStore: ${if (healthDataStore != null) "✅" else "❌"}")
            Log.d(TAG, "   - Has Permissions: ${if (hasPermissions) "✅" else "❌"}")

            // 即使没有权限，只要 store 初始化成功就返回 true
            return@withContext (healthDataStore != null)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to initialize Samsung Health", e)
            Log.e(TAG, "   - Error type: ${e.javaClass.simpleName}")
            Log.e(TAG, "   - Error message: ${e.message}")
            e.printStackTrace()
            false
        }
    }
    
    /**
     * 设置Activity实例
     */
    fun setActivity(activity: Activity?) {
        this.activity = activity
    }
    
    override suspend fun readTodayStepCount(): StepCountResult? {
        return readStepCountForDate(TimeCompat.LocalDate.now())
    }
    
    override suspend fun readStepCountForDate(date: TimeCompat.LocalDate): StepCountResult? = withContext(Dispatchers.IO) {
        try {
            val store = healthDataStore ?: return@withContext null
            
            // 转换为java.time.LocalDate（Samsung Health SDK需要）
            val javaDate = LocalDate.of(date.year, date.month, date.dayOfMonth)
            val stepsResponse = getAggregateResult(store, javaDate)
            var totalSteps = 0L
            
            stepsResponse.dataList.forEach { aggregatedData ->
                totalSteps += aggregatedData.value ?: 0L
            }
            
            Log.d(TAG, "Read steps for $date: $totalSteps")
            
            StepCountResult(
                totalSteps = totalSteps.toInt(),
                data = listOf(
                    StepData(
                        steps = totalSteps.toInt(),
                        timestamp = date.atStartOfDay(),
                        date = date.toString()
                    )
                ),
                dataSource = "samsung_health_sdk_official",
                metadata = mapOf(
                    "segmentCount" to stepsResponse.dataList.size,
                    "date" to date.toString()
                )
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read step count for date: $date", e)
            null
        }
    }
    
    override suspend fun readStepCountForDateRange(startDate: TimeCompat.LocalDate, endDate: TimeCompat.LocalDate): StepCountResult? {
        try {
            val dailyResults = mutableListOf<StepData>()
            var totalSteps = 0
            var currentDate = startDate

            while (!currentDate.isAfter(endDate)) {
                val dayResult = readStepCountForDate(currentDate)
                dayResult?.let { result ->
                    totalSteps += result.totalSteps
                    dailyResults.addAll(result.data)
                }
                currentDate = currentDate.plusDays(1)
            }

            return StepCountResult(
                totalSteps = totalSteps,
                data = dailyResults,
                dataSource = "samsung_health_sdk_official",
                metadata = mapOf(
                    "startDate" to startDate.toString(),
                    "endDate" to endDate.toString(),
                    "dayCount" to dailyResults.size
                )
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read step count for date range", e)
            return null
        }
    }

    override suspend fun checkPermissions(dataTypes: List<String>, operation: String): Map<String, Any> {
        return try {
            val store = healthDataStore ?: return emptyMap()
            val permissions = mutableMapOf<String, String>()

            dataTypes.forEach { dataType ->
                val permission = mapDataTypeToPermission(dataType, operation)
                if (permission != null) {
                    val granted = store.getGrantedPermissions(setOf(permission))
                    permissions[dataType] = if (granted.contains(permission)) "granted" else "denied"
                } else {
                    permissions[dataType] = "not_supported"
                }
            }

            permissions
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check permissions", e)
            emptyMap()
        }
    }

    override suspend fun requestPermissions(
        dataTypes: List<String>,
        operations: List<String>,
        reason: String?
    ): Boolean {
        try {
            Log.d(TAG, "🔐 ========== REQUEST PERMISSIONS START ==========")
            Log.d(TAG, "🔐 Data types: $dataTypes")
            Log.d(TAG, "🔐 Operations: $operations")
            Log.d(TAG, "🔐 Reason: $reason")

            val currentActivity = activity ?: run {
                Log.e(TAG, "❌ Activity is null, cannot request permissions")
                Log.e(TAG, "   💡 Hint: Make sure Activity is properly set via setActivity()")
                return false
            }
            Log.d(TAG, "✅ Activity available: ${currentActivity.javaClass.simpleName}")

            var store = healthDataStore
            if (store == null) {
                Log.w(TAG, "⚠️ HealthDataStore is null, attempting to re-initialize...")
                try {
                    store = HealthDataService.getStore(context)
                    healthDataStore = store
                    Log.d(TAG, "✅ HealthDataStore re-initialized successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Failed to re-initialize HealthDataStore", e)
                    return false
                }
            }

            if (store == null) {
                Log.e(TAG, "❌ HealthDataStore is still null after re-initialization attempt")
                Log.e(TAG, "   💡 Hint: Check if Samsung Health app is installed and updated")
                Log.e(TAG, "   💡 Hint: Check device API level (requires Android 10+)")
                return false
            }

            Log.d(TAG, "✅ HealthDataStore is ready")

            val permissionsToRequest = mutableSetOf<Permission>()

            dataTypes.forEach { dataType ->
                operations.forEach { operation ->
                    val permission = mapDataTypeToPermission(dataType, operation)
                    if (permission != null) {
                        permissionsToRequest.add(permission)
                        Log.d(TAG, "   ➕ Added permission: $dataType ($operation)")
                    } else {
                        Log.w(TAG, "   ⚠️ Unsupported permission: $dataType ($operation)")
                    }
                }
            }

            if (permissionsToRequest.isEmpty()) {
                Log.w(TAG, "⚠️ No valid permissions to request")
                return false
            }

            Log.d(TAG, "📋 Total permissions to request: ${permissionsToRequest.size}")
            permissionsToRequest.forEachIndexed { index, perm ->
                Log.d(TAG, "   ${index + 1}. $perm")
            }

            // requestPermissions must be called on the main thread
            return withContext(Dispatchers.Main) {
                try {
                    Log.d(TAG, "📱 Calling requestPermissions on Main thread...")
                    store.requestPermissions(permissionsToRequest, currentActivity)
                    Log.d(TAG, "✅ requestPermissions called successfully")

                    // Wait for user interaction
                    Log.d(TAG, "⏳ Waiting 2 seconds for user interaction...")
                    delay(2000)

                    // Check granted permissions on IO thread
                    withContext(Dispatchers.IO) {
                        Log.d(TAG, "🔍 Checking granted permissions...")
                        val grantedPermissions = store.getGrantedPermissions(permissionsToRequest)
                        val allGranted = grantedPermissions.containsAll(permissionsToRequest)

                        Log.d(TAG, "📊 Permissions granted: ${grantedPermissions.size}/${permissionsToRequest.size}")
                        grantedPermissions.forEach { perm ->
                            Log.d(TAG, "   ✅ $perm")
                        }

                        val denied = permissionsToRequest - grantedPermissions
                        if (denied.isNotEmpty()) {
                            Log.w(TAG, "⚠️ Denied permissions: ${denied.size}")
                            denied.forEach { perm ->
                                Log.w(TAG, "   ❌ $perm")
                            }
                        }

                        Log.d(TAG, "🔐 ========== REQUEST PERMISSIONS END: ${if (allGranted) "✅ SUCCESS" else "❌ PARTIAL/FAILED"} ==========")
                        allGranted
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Exception during permission request", e)
                    Log.e(TAG, "   - Error type: ${e.javaClass.simpleName}")
                    Log.e(TAG, "   - Error message: ${e.message}")
                    e.printStackTrace()
                    Log.d(TAG, "🔐 ========== REQUEST PERMISSIONS END: ❌ EXCEPTION ==========")
                    false
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Outer exception in requestPermissions", e)
            Log.d(TAG, "🔐 ========== REQUEST PERMISSIONS END: ❌ OUTER EXCEPTION ==========")
            return false
        }
    }

    override fun getSupportedDataTypes(operation: String?): List<String> {
        // 基于 Samsung Health Data SDK 23 个 DataTypes 的完整支持列表
        val readableTypes = listOf(
            // 基础运动指标
            "steps",                    // STEPS
            "distance",                 // ACTIVITY_SUMMARY
            "active_calories",          // ACTIVITY_SUMMARY
            "floors_climbed",           // FLOORS_CLIMBED

            // 心血管
            "heart_rate",               // HEART_RATE
            "blood_pressure_systolic",  // BLOOD_PRESSURE
            "blood_pressure_diastolic", // BLOOD_PRESSURE
            "oxygen_saturation",        // BLOOD_OXYGEN

            // 睡眠
            "sleep_duration",           // SLEEP
            "sleep_deep",               // SLEEP
            "sleep_light",              // SLEEP
            "sleep_rem",                // SLEEP

            // 运动
            "workout",                  // EXERCISE
            "workout_location",         // EXERCISE_LOCATION

            // 健康指标
            "glucose",                  // BLOOD_GLUCOSE
            "body_temperature",         // BODY_TEMPERATURE
            "skin_temperature",         // SKIN_TEMPERATURE

            // 身体成分
            "height",                   // BODY_COMPOSITION
            "weight",                   // BODY_COMPOSITION
            "body_fat",                 // BODY_COMPOSITION
            "bmi",                      // BODY_COMPOSITION

            // 营养
            "water",                    // WATER_INTAKE
            "nutrition",                // NUTRITION

            // 特殊类型
            "energy_score",             // ENERGY_SCORE
            "user_profile",             // USER_PROFILE

            // 目标类型 (Goal Types)
            "steps_goal",               // STEPS_GOAL
            "active_calories_goal",     // ACTIVE_CALORIES_BURNED_GOAL
            "active_time_goal",         // ACTIVE_TIME_GOAL
            "sleep_goal",               // SLEEP_GOAL
            "water_goal",               // WATER_INTAKE_GOAL
            "nutrition_goal"            // NUTRITION_GOAL
        )

        val writableTypes = listOf(
            // 血糖 - 可写
            "glucose",                  // BLOOD_GLUCOSE

            // 血压 - 可写
            "blood_pressure_systolic",  // BLOOD_PRESSURE
            "blood_pressure_diastolic", // BLOOD_PRESSURE

            // 体温 - 可写
            "body_temperature",         // BODY_TEMPERATURE

            // 身体成分 - 部分可写
            "weight",                   // BODY_COMPOSITION
            "height",                   // BODY_COMPOSITION

            // 营养 - 可写
            "water",                    // WATER_INTAKE
            "nutrition",                // NUTRITION

            // 用户资料 - 可写
            "user_profile"              // USER_PROFILE
        )

        return when (operation) {
            "write" -> writableTypes
            "read" -> readableTypes
            else -> readableTypes
        }
    }

    override fun isDataTypeSupported(dataType: String, operation: String): Boolean {
        return getSupportedDataTypes(operation).contains(dataType)
    }

    override fun getPlatformCapabilities(): List<Map<String, Any>> {
        val capabilities = mutableListOf<Map<String, Any>>()
        val allTypes = getSupportedDataTypes(null).toSet()

        allTypes.forEach { dataType ->
            capabilities.add(mapOf(
                "dataType" to dataType,
                "canRead" to isDataTypeSupported(dataType, "read"),
                "canWrite" to isDataTypeSupported(dataType, "write"),
                "specialNotes" to ""
            ))
        }

        return capabilities
    }

    override suspend fun readHealthData(
        dataType: String,
        startDate: TimeCompat.LocalDate?,
        endDate: TimeCompat.LocalDate?,
        limit: Int?
    ): HealthDataResult? {
        return try {
            // For now, only implement steps data
            if (dataType == "steps") {
                val start = startDate ?: TimeCompat.LocalDate.now()
                val end = endDate ?: TimeCompat.LocalDate.now()

                val stepResult = readStepCountForDateRange(start, end)
                stepResult?.let {
                    HealthDataResult(
                        data = it.data.map { stepData ->
                            mapOf(
                                "type" to "steps",
                                "value" to stepData.steps.toDouble(),
                                "timestamp" to stepData.timestamp,
                                "unit" to "steps",
                                "platform" to platformKey
                            )
                        },
                        dataSource = it.dataSource,
                        metadata = it.metadata
                    )
                }
            } else {
                // Other data types not yet implemented
                Log.w(TAG, "Data type $dataType not yet implemented")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read health data for type: $dataType", e)
            null
        }
    }

    override suspend fun writeHealthData(dataMap: Map<String, Any>): Boolean {
        // Writing data to Samsung Health requires specific implementation
        // For now, return false (not implemented)
        Log.w(TAG, "Write health data not yet implemented for Samsung Health")
        return false
    }

    override suspend fun writeBatchHealthData(dataList: List<Map<String, Any>>): Boolean {
        // Batch writing not yet implemented
        Log.w(TAG, "Batch write health data not yet implemented for Samsung Health")
        return false
    }

    /**
     * Map data type string to Samsung Health Permission
     * 完整映射 Samsung Health Data SDK 的 23 个 DataTypes
     * 参考: https://developer.samsung.com/health/data/api-reference
     */
    private fun mapDataTypeToPermission(dataType: String, operation: String): Permission? {
        val accessType = when (operation) {
            "read" -> AccessType.READ
            "write" -> AccessType.WRITE
            else -> AccessType.READ
        }

        return try {
            when (dataType) {
                // 1. STEPS - 步数
                "steps" -> Permission.of(DataTypes.STEPS, accessType)

                // 2. HEART_RATE - 心率
                "heart_rate" -> Permission.of(DataTypes.HEART_RATE, accessType)

                // 3. SLEEP - 睡眠（所有睡眠阶段映射到同一个 DataType）
                "sleep_duration", "sleep_deep", "sleep_light", "sleep_rem" ->
                    Permission.of(DataTypes.SLEEP, accessType)

                // 4. EXERCISE - 运动
                "workout" -> Permission.of(DataTypes.EXERCISE, accessType)

                // 5. EXERCISE_LOCATION - 运动位置
                "workout_location" -> Permission.of(DataTypes.EXERCISE_LOCATION, accessType)

                // 6. BLOOD_PRESSURE - 血压（收缩压和舒张压）
                "blood_pressure_systolic", "blood_pressure_diastolic" ->
                    Permission.of(DataTypes.BLOOD_PRESSURE, accessType)

                // 7. BLOOD_GLUCOSE - 血糖
                "glucose" -> Permission.of(DataTypes.BLOOD_GLUCOSE, accessType)

                // 8. BLOOD_OXYGEN - 血氧
                "oxygen_saturation" -> Permission.of(DataTypes.BLOOD_OXYGEN, accessType)

                // 9. BODY_TEMPERATURE - 体温
                "body_temperature" -> Permission.of(DataTypes.BODY_TEMPERATURE, accessType)

                // 10. SKIN_TEMPERATURE - 皮肤温度
                "skin_temperature" -> Permission.of(DataTypes.SKIN_TEMPERATURE, accessType)

                // 11. BODY_COMPOSITION - 身体成分（体重、身高、体脂、BMI）
                "height", "weight", "body_fat", "bmi" ->
                    Permission.of(DataTypes.BODY_COMPOSITION, accessType)

                // 12. WATER_INTAKE - 饮水量
                "water" -> Permission.of(DataTypes.WATER_INTAKE, accessType)

                // 13. NUTRITION - 营养
                "nutrition" -> Permission.of(DataTypes.NUTRITION, accessType)

                // 14. FLOORS_CLIMBED - 爬楼层数
                "floors_climbed" -> Permission.of(DataTypes.FLOORS_CLIMBED, accessType)

                // 15. ACTIVITY_SUMMARY - 活动总结（活动卡路里、距离等）
                "active_calories", "distance" ->
                    Permission.of(DataTypes.ACTIVITY_SUMMARY, accessType)

                // 16. ENERGY_SCORE - 能量分数
                "energy_score" -> Permission.of(DataTypes.ENERGY_SCORE, accessType)

                // 17. USER_PROFILE - 用户资料
                "user_profile" -> Permission.of(DataTypes.USER_PROFILE, accessType)

                // 18. STEPS_GOAL - 步数目标
                "steps_goal" -> Permission.of(DataTypes.STEPS_GOAL, accessType)

                // 19. ACTIVE_CALORIES_BURNED_GOAL - 活动卡路里目标
                "active_calories_goal" -> Permission.of(DataTypes.ACTIVE_CALORIES_BURNED_GOAL, accessType)

                // 20. ACTIVE_TIME_GOAL - 活动时间目标
                "active_time_goal" -> Permission.of(DataTypes.ACTIVE_TIME_GOAL, accessType)

                // 21. SLEEP_GOAL - 睡眠目标
                "sleep_goal" -> Permission.of(DataTypes.SLEEP_GOAL, accessType)

                // 22. WATER_INTAKE_GOAL - 饮水目标
                "water_goal" -> Permission.of(DataTypes.WATER_INTAKE_GOAL, accessType)

                // 23. NUTRITION_GOAL - 营养目标
                "nutrition_goal" -> Permission.of(DataTypes.NUTRITION_GOAL, accessType)

                else -> {
                    Log.w(TAG, "⚠️ No Samsung Health DataType mapping for: $dataType")
                    null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error mapping data type: $dataType", e)
            null
        }
    }

    override fun cleanup() {
        healthDataStore = null
        hasPermissions = false
        Log.d(TAG, "Samsung Health provider cleaned up")
    }
    
    /**
     * 获取聚合步数结果
     */
    private fun getAggregateResult(
        store: HealthDataStore,
        date: LocalDate
    ): DataResponse<AggregatedData<Long>> {
        val stepsRequest = DataType.StepsType.TOTAL.requestBuilder.setLocalTimeFilterWithGroup(
            LocalTimeFilter.of(date.atStartOfDay(), date.plusDays(1).atStartOfDay()),
            LocalTimeGroup.of(LocalTimeGroupUnit.MINUTELY, 30)
        ).build()
        
        return store.aggregateDataAsync(stepsRequest).get()
    }
    
    /**
     * 检查和请求权限 - 恢复原始逻辑
     */
    private suspend fun checkAndRequestPermissions(activity: Activity): Boolean = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "🔐 开始检查和请求Samsung Health权限...")
            
            val store = healthDataStore ?: run {
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
            val grantedPermissions = store.getGrantedPermissions(requiredPermissions)
            Log.d(TAG, "📊 当前已授予权限数量: ${grantedPermissions.size}/${requiredPermissions.size}")
            
            if (grantedPermissions.containsAll(requiredPermissions)) {
                Log.d(TAG, "✅ 所有必需权限已授予")
                return@withContext true
            }
            
            // 申请缺失的权限
            Log.d(TAG, "🚨 发现缺失权限，开始申请...")
            val missingPermissions = requiredPermissions - grantedPermissions
            Log.d(TAG, "   - 缺失权限数量: ${missingPermissions.size}")
            
            // 申请权限 - 会弹出Samsung Health权限对话框
            Log.d(TAG, "📱 发起权限申请对话框...")
            store.requestPermissions(requiredPermissions, activity)
            
            // 等待用户操作后重新检查权限
            Log.d(TAG, "⏳ 等待用户授权操作...")
            delay(1500) // 给用户足够时间操作
            
            val finalPermissions = store.getGrantedPermissions(requiredPermissions)
            val allGranted = finalPermissions.containsAll(requiredPermissions)
            
            Log.d(TAG, "📈 权限申请后检查: ${finalPermissions.size}/${requiredPermissions.size}")
            Log.d(TAG, if (allGranted) "✅ 权限申请成功" else "⚠️ 权限申请被拒绝或部分授予")
            
            return@withContext allGranted
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ 权限检查/申请失败: ${e.message}", e)
            return@withContext false
        }
    }
}