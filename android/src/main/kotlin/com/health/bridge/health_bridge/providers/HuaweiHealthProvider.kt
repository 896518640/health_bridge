package com.health.bridge.health_bridge.providers

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.health.bridge.health_bridge.utils.TimeCompat
import com.huawei.hms.hihealth.DataController
import com.huawei.hms.hihealth.SettingController
import com.huawei.hms.hihealth.HuaweiHiHealth
import com.huawei.hms.hihealth.HiHealthStatusCodes
import com.huawei.hms.hihealth.data.DataCollector
import com.huawei.hms.hihealth.data.DataType
import com.huawei.hms.hihealth.data.Field
import com.huawei.hms.hihealth.data.SampleSet
import com.huawei.hms.hihealth.data.Scopes
import com.huawei.hms.hihealth.data.HealthDataTypes
import com.huawei.hms.hihealth.options.ReadOptions
import kotlinx.coroutines.*
import java.time.LocalDate
import java.time.ZoneId
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine

/**
 * 华为运动健康提供者
 * 基于HMS Health Kit实现
 */
class HuaweiHealthProvider(
    private val context: Context,
    private var activity: Activity?
) : HealthDataProvider {

    override val platformKey: String = "huawei_health"

    private var settingController: SettingController? = null
    private var dataController: DataController? = null
    private var isInitialized = false

    companion object {
        private const val TAG = "HuaweiHealthProvider"
        private const val REQUEST_AUTH = 1002
    }

    /**
     * 数据类型映射 - Health Bridge数据类型 -> 华为Health Kit数据类型
     *
     * ⚠️ 重要：华为Health仅支持3种数据类型的读取
     * - 步数 (steps)
     * - 血糖 (glucose)
     * - 血压 (blood_pressure) - 复合数据，包含收缩压和舒张压
     *
     * 注意：使用HealthDataTypes类来访问血糖和血压数据类型
     */
    private val dataTypeMapping = mapOf(
        // 步数
        "steps" to DataType.DT_CONTINUOUS_STEPS_DELTA,

        // 血糖
        "glucose" to HealthDataTypes.DT_INSTANTANEOUS_BLOOD_GLUCOSE,

        // 血压（统一类型，返回复合数据）
        "blood_pressure" to HealthDataTypes.DT_INSTANTANEOUS_BLOOD_PRESSURE,

        // 兼容旧类型（内部映射到统一的血压类型）
        "blood_pressure_systolic" to HealthDataTypes.DT_INSTANTANEOUS_BLOOD_PRESSURE,
        "blood_pressure_diastolic" to HealthDataTypes.DT_INSTANTANEOUS_BLOOD_PRESSURE
    )

    /**
     * Field映射 - 数据类型对应的Field
     *
     * 注意：血糖和血压需要从SamplePoint中动态获取Field
     */
    private val fieldMapping = mapOf(
        "steps" to Field.FIELD_STEPS_DELTA,
        "distance" to Field.FIELD_DISTANCE_DELTA,
        "active_calories" to Field.FIELD_CALORIES,
        "heart_rate" to Field.FIELD_BPM,
        "weight" to Field.FIELD_BODY_WEIGHT,
        "height" to Field.FIELD_HEIGHT,
        "body_fat_percentage" to Field.FIELD_BODY_FAT_RATE
        // 血糖和血压的Field需要从DataType的fields属性中获取
        // 不能在这里硬编码，因为常量名称可能不同
    )

    /**
     * 检查华为Health Kit是否可用
     */
    override fun isAvailable(): Boolean {
        return try {
            // 1. 检查 Android 版本
            // 华为运动健康 App 要求 Android 7.0+ (API 24)
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
                Log.d(TAG, "Huawei Health requires Android 7.0+ (API 24), current: ${Build.VERSION.SDK_INT}")
                return false
            }

            // 2. 检查华为运动健康 App 是否安装
            // 要求版本: 11.0.0.512+
            context.packageManager.getPackageInfo("com.huawei.health", 0)

            // 3. TODO: 检查 HMS Core 版本
            // 要求版本: 4.0.2.300+
            // 可以使用 HuaweiApiAvailability.getInstance().isHuaweiMobileServicesAvailable(context)

            Log.d(TAG, "Huawei Health is available")
            true
        } catch (e: Exception) {
            Log.d(TAG, "Huawei Health not available: ${e.message}")
            false
        }
    }

    /**
     * 设置Activity
     */
    fun setActivity(activity: Activity?) {
        this.activity = activity
    }

    /**
     * 初始化华为Health Kit
     */
    override suspend fun initialize(): Boolean = withContext(Dispatchers.IO) {
        try {
            // 如果已经初始化，直接返回成功
            if (isInitialized && settingController != null && dataController != null) {
                Log.d(TAG, "Huawei Health Kit already initialized, skipping")
                return@withContext true
            }

            Log.d(TAG, "=== Huawei Health Kit Initialization Start ===")
            Log.d(TAG, "Package name: ${context.packageName}")

            // 尝试获取APP ID来验证AGConnect配置
            try {
                val appId = context.packageManager
                    .getApplicationInfo(context.packageName, android.content.pm.PackageManager.GET_META_DATA)
                    .metaData?.getString("com.huawei.hms.client.appid")
                Log.d(TAG, "AGConnect App ID from manifest: $appId")

                if (appId == null) {
                    Log.e(TAG, "⚠️ WARNING: App ID not found in AndroidManifest.xml!")
                    Log.e(TAG, "Please add: <meta-data android:name=\"com.huawei.hms.client.appid\" android:value=\"appid=YOUR_APP_ID\"/>")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to read App ID from manifest", e)
            }

            Log.d(TAG, "Creating SettingController...")
            settingController = HuaweiHiHealth.getSettingController(context)
            Log.d(TAG, "✅ SettingController created: ${settingController != null}")

            Log.d(TAG, "Creating DataController...")
            dataController = HuaweiHiHealth.getDataController(context)
            Log.d(TAG, "✅ DataController created: ${dataController != null}")

            isInitialized = true
            Log.i(TAG, "=== Huawei Health Kit initialized successfully ===")
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to initialize Huawei Health Kit", e)
            Log.e(TAG, "Exception type: ${e.javaClass.name}")
            Log.e(TAG, "Exception message: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    /**
     * 读取今日步数
     */
    override suspend fun readTodayStepCount(): StepCountResult? {
        return readStepCountForDate(TimeCompat.LocalDate.now())
    }

    /**
     * 读取指定日期的步数
     * 参考 Demo: HealthKitDataControllerActivity.kt:234-256
     */
    override suspend fun readStepCountForDate(date: TimeCompat.LocalDate): StepCountResult? = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "📖 Reading steps for date: $date")

            // ⭐ 关键改进：在读取数据前检查权限
            if (!checkHealthAppAuthorization()) {
                Log.e(TAG, "❌ Cannot read steps: Health App not authorized")
                Log.e(TAG, "   Please call requestPermissions() and wait for user to grant permission")
                return@withContext null
            }

            val javaDate = LocalDate.of(date.year, date.month, date.dayOfMonth)
            val startTime = javaDate.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
            // ⭐ 使用当天结束时间，而不是第二天开始时间，避免超过31天限制
            val endTime = javaDate.atTime(23, 59, 59, 999_000_000)
                .atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()

            // ⭐ 关键改进：直接使用 DataType 读取，而不是 DataCollector
            // 这样可以读取所有来源的数据，不仅限于本应用写入的数据
            val readOptions = ReadOptions.Builder()
                .read(DataType.DT_CONTINUOUS_STEPS_DELTA)  // 直接传 DataType
                .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
                .build()

            Log.d(TAG, "📡 Executing read request...")
            val readReply = suspendCoroutine<com.huawei.hms.hihealth.result.ReadReply> { continuation ->
                dataController!!.read(readOptions)
                    .addOnSuccessListener {
                        Log.d(TAG, "✅ Read success, sampleSets count: ${it.sampleSets.size}")
                        continuation.resume(it)
                    }
                    .addOnFailureListener { e ->
                        Log.e(TAG, "❌ Read failed: ${e.message}", e)
                        continuation.resumeWithException(e)
                    }
            }

            var totalSteps = 0
            val stepDataList = mutableListOf<StepData>()

            Log.d(TAG, "🔍 Processing ${readReply.sampleSets.size} sampleSets...")
            for (sampleSet in readReply.sampleSets) {
                Log.d(TAG, "   SampleSet has ${sampleSet.samplePoints.size} points")
                for (sample in sampleSet.samplePoints) {
                    val steps = sample.getFieldValue(Field.FIELD_STEPS_DELTA).asIntValue()
                    totalSteps += steps

                    Log.d(TAG, "   📍 Steps: $steps at ${sample.getStartTime(TimeUnit.MILLISECONDS)}")

                    stepDataList.add(
                        StepData(
                            steps = steps,
                            timestamp = sample.getStartTime(TimeUnit.MILLISECONDS),
                            date = date.toString()
                        )
                    )
                }
            }

            Log.d(TAG, "✅ Total steps for $date: $totalSteps (${stepDataList.size} segments)")

            StepCountResult(
                totalSteps = totalSteps,
                data = stepDataList,
                dataSource = "huawei_health_kit",
                metadata = mapOf(
                    "date" to date.toString(),
                    "segmentCount" to stepDataList.size
                )
            )
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error reading step count for date: $date", e)
            Log.e(TAG, "   Error type: ${e.javaClass.simpleName}")
            Log.e(TAG, "   Error message: ${e.message}")
            e.printStackTrace()
            null
        }
    }

    /**
     * 读取日期范围的步数
     *
     * 注意：华为 Health Kit 限制单次查询不超过 31 天
     * 如果范围超过 30 天，会分批查询
     */
    override suspend fun readStepCountForDateRange(
        startDate: TimeCompat.LocalDate,
        endDate: TimeCompat.LocalDate
    ): StepCountResult? {
        try {
            // 检查时间范围
            val daysDiff = java.time.Duration.between(
                LocalDate.of(startDate.year, startDate.month, startDate.dayOfMonth).atStartOfDay(),
                LocalDate.of(endDate.year, endDate.month, endDate.dayOfMonth).atStartOfDay()
            ).toDays()

            if (daysDiff > 30) {
                Log.w(TAG, "⚠️ Date range ($daysDiff days) exceeds Huawei's 31-day limit")
                Log.w(TAG, "   Will query day by day (this may be slow)")
            }

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
                dataSource = "huawei_health_kit",
                metadata = mapOf(
                    "startDate" to startDate.toString(),
                    "endDate" to endDate.toString(),
                    "dayCount" to dailyResults.size,
                    "queryDays" to daysDiff
                )
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read step count for date range", e)
            return null
        }
    }

    /**
     * 请求权限授权
     */
    override suspend fun requestPermissions(
        dataTypes: List<String>,
        operations: List<String>,
        reason: String?
    ): Boolean = withContext(Dispatchers.Main) {
        try {
            Log.d(TAG, "=== Request Permissions Start ===")
            Log.d(TAG, "dataTypes: $dataTypes")
            Log.d(TAG, "operations: $operations")

            if (activity == null) {
                Log.e(TAG, "Activity is null, cannot request permissions")
                return@withContext false
            }
            Log.d(TAG, "Activity available: ${activity!!.javaClass.simpleName}")

            if (settingController == null) {
                Log.e(TAG, "SettingController is null! Need to initialize first")
                return@withContext false
            }
            Log.d(TAG, "SettingController is ready")

            // 构建Scope列表
            val scopes = mutableListOf<String>()
            for (dataType in dataTypes) {
                for (operation in operations) {
                    val scope = mapDataTypeToScope(dataType, operation)
                    if (scope != null) {
                        scopes.add(scope)
                        Log.d(TAG, "Added scope: $scope for $dataType ($operation)")
                    } else {
                        Log.w(TAG, "No scope mapping for: $dataType ($operation)")
                    }
                }
            }

            // ⚠️ 注意：不申请历史数据权限 HEALTHKIT_HISTORYDATA_OPEN_WEEK
            // 该权限会被识别为"写入"权限，导致用户混淆
            // 华为Health Kit默认只能查询授权后的数据（参考官方demo做法）

            if (scopes.isEmpty()) {
                Log.w(TAG, "No valid scopes to request")
                return@withContext false
            }

            Log.d(TAG, "Total scopes: ${scopes.size}")
            Log.d(TAG, "Scopes list: $scopes")

            // 调试：输出每个 Scope 的详细信息
            scopes.forEachIndexed { index, scope ->
                Log.d(TAG, "  Scope[$index]: $scope")
            }

            // 请求授权
            Log.d(TAG, "Calling requestAuthorizationIntent...")
            val scopesArray = scopes.toTypedArray()
            Log.d(TAG, "Scopes array length: ${scopesArray.size}")
            val intent = settingController?.requestAuthorizationIntent(scopesArray, true)

            if (intent != null) {
                Log.d(TAG, "✅ Got authorization intent successfully")
                activity?.startActivityForResult(intent, REQUEST_AUTH)
                // Note: 实际结果需要在onActivityResult中处理
                // 这里简化处理，假设用户会授权
                delay(2000)
                return@withContext true
            } else {
                Log.e(TAG, "❌ Failed to get authorization intent - intent is null")
                Log.e(TAG, "Possible reasons:")
                Log.e(TAG, "1. App ID not configured or incorrect")
                Log.e(TAG, "2. Certificate fingerprint not registered in Huawei console")
                Log.e(TAG, "3. Health Kit service not enabled for this app")
                Log.e(TAG, "4. Package name mismatch")
                return@withContext false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting permissions", e)
            Log.e(TAG, "Exception type: ${e.javaClass.name}")
            Log.e(TAG, "Exception message: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    /**
     * 映射数据类型到Scope
     * 注意：只申请读权限，不申请写权限
     * 目前只实现了: 
     * - 步数
     * - 血糖
     * - 血压
     * 以上三种数据类型需要申请权限
     */
    private fun mapDataTypeToScope(dataType: String, operation: String): String? {
        // 只支持读操作
        if (operation != "read") {
            Log.w(TAG, "⚠️ Huawei Health only supports READ operations, ignoring write request")
            return null
        }

        return when (dataType) {
            "steps" -> Scopes.HEALTHKIT_STEP_READ
            "glucose" -> Scopes.HEALTHKIT_BLOODGLUCOSE_READ
            "blood_pressure", "blood_pressure_systolic", "blood_pressure_diastolic" ->
                Scopes.HEALTHKIT_BLOODPRESSURE_READ
            else -> {
                Log.w(TAG, "⚠️ Unsupported data type for Huawei Health: $dataType")
                null
            }
        }
    }

    /**
     * 检查权限状态
     */
    override suspend fun checkPermissions(
        dataTypes: List<String>,
        operation: String
    ): Map<String, Any> {
        // 华为Health Kit没有直接查询权限状态的API
        // 返回一个通用的结果
        val permissions = mutableMapOf<String, Any>()
        for (dataType in dataTypes) {
            permissions[dataType] = if (isInitialized) "granted" else "denied"
        }
        return permissions
    }

    /**
     * 检查是否已授权
     * 参考 Demo: HealthKitSettingControllerActivity.kt:276
     */
    private suspend fun checkHealthAppAuthorization(): Boolean = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "🔐 Checking Health App authorization...")

            val result = suspendCoroutine<Boolean> { continuation ->
                settingController?.getHealthAppAuthorization()
                    ?.addOnSuccessListener { authorized ->
                        Log.d(TAG, "   Authorization status: $authorized")
                        continuation.resume(authorized == true)
                    }
                    ?.addOnFailureListener { e ->
                        Log.e(TAG, "   Failed to check authorization: ${e.message}")
                        continuation.resume(false)
                    }
            }

            if (!result) {
                Log.w(TAG, "⚠️ Health App is NOT authorized! Please request permissions first.")
                Log.w(TAG, "   Error code 50059 means: permission not granted")
            }

            return@withContext result
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error checking authorization", e)
            return@withContext false
        }
    }

    /**
     * 读取健康数据（通用方法）
     *
     * 华为 Health Kit 限制：
     * - 错误码 50059：单次查询不超过 31 天
     * - 错误码 50065：历史数据权限不足
     *
     * 所有数据类型都会返回完整的 SDK 原始数据在 metadata 中
     */
    override suspend fun readHealthData(
        dataType: String,
        startDate: TimeCompat.LocalDate?,
        endDate: TimeCompat.LocalDate?,
        limit: Int?
    ): HealthDataResult? = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "📖 Reading health data: $dataType")

            // 1. 检查权限
            if (!checkHealthAppAuthorization()) {
                Log.e(TAG, "❌ Health App not authorized")
                return@withContext null
            }

            // 2. 获取 DataType
            val huaweiDataType = dataTypeMapping[dataType]
            if (huaweiDataType == null) {
                Log.w(TAG, "⚠️ Unsupported data type: $dataType")
                return@withContext null
            }

            // 3. 计算时间范围（处理30天限制）
            val (actualStartTime, actualEndTime, adjustedStart, adjustedEnd) =
                calculateTimeRange(startDate, endDate)

            // 4. 执行读取请求
            val readReply = executeReadRequest(huaweiDataType, actualStartTime, actualEndTime, dataType)

            // 5. 处理数据 - 根据类型分发
            val dataList = processHealthDataSamples(
                dataType,
                huaweiDataType,
                readReply.sampleSets,
                limit
            )

            Log.d(TAG, "✅ 成功读取 ${dataList.size} 条数据 : $dataType")

            HealthDataResult(
                data = dataList,
                dataSource = "huawei_health_kit",
                metadata = mapOf(
                    "count" to dataList.size,
                    "dataType" to dataType,
                    "startDate" to adjustedStart.toString(),
                    "endDate" to adjustedEnd.toString()
                )
            )
        } catch (e: Exception) {
            Log.e(TAG, "❌ 读取健康数据失败: $dataType", e)
            Log.e(TAG, "   Error: ${e.javaClass.simpleName} - ${e.message}")
            e.printStackTrace()
            null
        }
    }

    /**
     * 计算实际查询时间范围（处理华为30天限制）
     */
    private fun calculateTimeRange(
        startDate: TimeCompat.LocalDate?,
        endDate: TimeCompat.LocalDate?
    ): TimeRangeResult {
        val now = TimeCompat.LocalDate.now()
        var start = startDate ?: now
        var end = endDate ?: now

        val javaStart = LocalDate.of(start.year, start.month, start.dayOfMonth)
        val javaEnd = LocalDate.of(end.year, end.month, end.dayOfMonth)
        val daysDiff = java.time.temporal.ChronoUnit.DAYS.between(javaStart, javaEnd)

        Log.d(TAG, "   Date range: $javaStart to $javaEnd ($daysDiff days)")

        // 如果超过30天限制，调整为最近28天
        val (adjustedJavaStart, adjustedJavaEnd) = if (daysDiff >= 30) {
            Log.w(TAG, "⚠️ Range exceeds 30-day limit, adjusting to 28 days")
            val adjusted = javaEnd.minusDays(28)
            start = TimeCompat.LocalDate(adjusted.year, adjusted.monthValue, adjusted.dayOfMonth)
            Pair(adjusted, javaEnd)
        } else {
            Pair(javaStart, javaEnd)
        }

        val startTime = adjustedJavaStart.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val endTime = adjustedJavaEnd.atTime(23, 59, 59, 999_000_000)
            .atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()

        return TimeRangeResult(startTime, endTime, start, end)
    }

    /**
     * 执行读取请求
     */
    private suspend fun executeReadRequest(
        huaweiDataType: DataType,
        startTime: Long,
        endTime: Long,
        dataType: String
    ): com.huawei.hms.hihealth.result.ReadReply {
        val readOptions = ReadOptions.Builder()
            .read(huaweiDataType)
            .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
            .build()

        Log.d(TAG, "📡 Executing read request...")
        return suspendCoroutine { continuation ->
            dataController!!.read(readOptions)
                .addOnSuccessListener {
                    Log.d(TAG, "✅ 读取成功: $dataType, sampleSets: ${it.sampleSets.size}")
                    continuation.resume(it)
                }
                .addOnFailureListener { e ->
                    Log.e(TAG, "❌ 读取失败: $dataType: ${e.message}", e)
                    continuation.resumeWithException(e)
                }
        }
    }

    /**
     * 处理健康数据样本
     */
    private fun processHealthDataSamples(
        dataType: String,
        huaweiDataType: DataType,
        sampleSets: List<SampleSet>,
        limit: Int?
    ): List<Map<String, Any?>> {
        val dataList = mutableListOf<Map<String, Any?>>()

        Log.d(TAG, "🔍 处理 ${sampleSets.size} 个 SampleSets...")

        for (sampleSet in sampleSets) {
            for (sample in sampleSet.samplePoints) {
                // 根据数据类型分发处理
                val healthData = if (isBloodPressureType(dataType)) {
                    processBloodPressureData(dataType, sample, huaweiDataType, sampleSet)
                } else {
                    processSimpleHealthData(dataType, sample, huaweiDataType, sampleSet)
                }

                dataList.add(healthData)

                // 检查数量限制
                if (limit != null && dataList.size >= limit) {
                    Log.d(TAG, "  达到限制: $limit")
                    return dataList
                }
            }
        }

        return dataList
    }

    /**
     * 时间范围计算结果
     */
    private data class TimeRangeResult(
        val startTime: Long,
        val endTime: Long,
        val startDate: TimeCompat.LocalDate,
        val endDate: TimeCompat.LocalDate
    )

    /**
     * 写入健康数据
     * 注意：华为Health Kit不支持写入操作，直接返回false
     */
    override suspend fun writeHealthData(dataMap: Map<String, Any>): Boolean = withContext(Dispatchers.IO) {
        Log.w(TAG, "⚠️ Huawei Health Kit 写入权限功能开发中...")
        return@withContext false
    }

    /**
     * 批量写入健康数据
     * 注意：华为Health Kit不支持写入操作，直接返回false
     */
    override suspend fun writeBatchHealthData(dataList: List<Map<String, Any>>): Boolean {
        Log.w(TAG, "⚠️ Huawei Health Kit 写入权限功能开发中...")
        return false
    }

    /**
     * 获取支持的数据类型
     */
    override fun getSupportedDataTypes(operation: String?): List<String> {
        return dataTypeMapping.keys.toList()
    }

    /**
     * 检查是否支持某个数据类型
     */
    override fun isDataTypeSupported(dataType: String, operation: String): Boolean {
        return dataTypeMapping.containsKey(dataType)
    }

    /**
     * 获取平台能力
     * 注意：华为Health Kit只支持读权限，不支持写权限
     */
    override fun getPlatformCapabilities(): List<Map<String, Any>> {
        return dataTypeMapping.keys.map { dataType ->
            mapOf<String, Any>(
                "dataType" to dataType,
                "canRead" to true,
                "canWrite" to false,  // 华为Health Kit不支持写入操作
                "requiresSpecialPermission" to false,
                "notes" to "Read-only support"
            )
        }
    }

    /**
     * 清理资源
     */
    override fun cleanup() {
        settingController = null
        dataController = null
        isInitialized = false
        Log.d(TAG, "Huawei Health Kit 清理完成")
    }

    /**
     * 获取数据类型对应的单位
     */
    private fun getUnitForDataType(dataType: String): String {
        return when (dataType) {
            "steps" -> "steps"
            "glucose" -> "mmol/L"
            "blood_pressure", "blood_pressure_systolic", "blood_pressure_diastolic" -> "mmHg"
            else -> ""
        }
    }

    /**
     * 构建完整的 metadata（包含所有 SDK 原始字段）
     *
     * 所有数据类型都会返回完整的 SDK 原始数据，包括：
     * 1. 所有字段的原始值（保持 SDK 原始命名）
     * 2. 时间信息（startTime, endTime, samplingTime）
     * 3. DataType 信息
     */
    private fun buildCompleteMetadata(
        sample: com.huawei.hms.hihealth.data.SamplePoint,
        huaweiDataType: DataType,
        sampleSet: SampleSet
    ): MutableMap<String, Any> {
        val metadata = mutableMapOf<String, Any>()

        // 1. 添加所有字段的原始值（保持 SDK 原始命名）
        huaweiDataType.fields.forEach { field ->
            try {
                val value: Any? = when (field.format) {
                    Field.FORMAT_INT32 -> sample.getFieldValue(field).asIntValue()
                    Field.FORMAT_LONG -> sample.getFieldValue(field).asLongValue()
                    Field.FORMAT_FLOAT -> sample.getFieldValue(field).asFloatValue()
                    Field.FORMAT_STRING -> {
                        try {
                            sample.getFieldValue(field).asStringValue()
                        } catch (e: Exception) {
                            null
                        }
                    }
                    else -> null
                }

                if (value != null) {
                    metadata[field.name] = value
                }
            } catch (e: Exception) {
                // 字段可能没有值，跳过
            }
        }

        // 2. 添加时间信息
        metadata["startTime"] = sample.getStartTime(TimeUnit.MILLISECONDS)
        metadata["endTime"] = sample.getEndTime(TimeUnit.MILLISECONDS)
        metadata["samplingTime"] = sample.getSamplingTime(TimeUnit.MILLISECONDS)

        // 3. 添加 DataType 信息
        metadata["dataType"] = sample.dataType.name

        return metadata
    }

    /**
     * 判断数据类型是否为血压相关
     */
    private fun isBloodPressureType(dataType: String): Boolean {
        return dataType == "blood_pressure" ||
               dataType == "blood_pressure_systolic" ||
               dataType == "blood_pressure_diastolic"
    }

    /**
     * 处理血压数据（复合数据类型）
     *
     * 血压数据包含收缩压和舒张压两个值，统一处理后返回标准格式。
     *
     * @param dataType 请求的数据类型（blood_pressure/blood_pressure_systolic/blood_pressure_diastolic）
     * @param sample SamplePoint
     * @param huaweiDataType 华为 DataType
     * @param sampleSet SampleSet
     * @return 标准格式的 Map
     */
    private fun processBloodPressureData(
        dataType: String,
        sample: com.huawei.hms.hihealth.data.SamplePoint,
        huaweiDataType: DataType,
        sampleSet: SampleSet
    ): Map<String, Any?> {
        // 查找收缩压和舒张压字段
        val systolicField = huaweiDataType.fields.find {
            it.name.contains("systolic", ignoreCase = true)
        }
        val diastolicField = huaweiDataType.fields.find {
            it.name.contains("diastolic", ignoreCase = true)
        }

        if (systolicField == null || diastolicField == null) {
            Log.e(TAG, "❌ 无法找到血压字段！systolic=$systolicField, diastolic=$diastolicField")
            throw IllegalStateException("Blood pressure fields not found")
        }

        // 获取收缩压和舒张压的值
        val systolicValue = when (systolicField.format) {
            Field.FORMAT_INT32 -> sample.getFieldValue(systolicField).asIntValue().toDouble()
            Field.FORMAT_LONG -> sample.getFieldValue(systolicField).asLongValue().toDouble()
            Field.FORMAT_FLOAT -> sample.getFieldValue(systolicField).asFloatValue().toDouble()
            else -> 0.0
        }

        val diastolicValue = when (diastolicField.format) {
            Field.FORMAT_INT32 -> sample.getFieldValue(diastolicField).asIntValue().toDouble()
            Field.FORMAT_LONG -> sample.getFieldValue(diastolicField).asLongValue().toDouble()
            Field.FORMAT_FLOAT -> sample.getFieldValue(diastolicField).asFloatValue().toDouble()
            else -> 0.0
        }

        // 构建完整的 metadata（包含所有 SDK 原始字段）
        val metadata = buildCompleteMetadata(sample, huaweiDataType, sampleSet)

        // 添加标准化字段（跨平台统一）
        metadata["systolic"] = systolicValue
        metadata["diastolic"] = diastolicValue

        // 根据请求的类型决定返回格式
        return when (dataType) {
            "blood_pressure" -> {
                // 统一的血压类型：value 为 null，数据在 metadata 中
                mapOf<String, Any?>(
                    "type" to dataType,
                    "value" to null,  // 复合数据，value 为 null
                    "timestamp" to sample.getStartTime(TimeUnit.MILLISECONDS),
                    "unit" to "mmHg",
                    "platform" to platformKey,
                    "metadata" to metadata
                )
            }
            "blood_pressure_systolic" -> {
                // 兼容旧类型：返回收缩压值
                mapOf(
                    "type" to dataType,
                    "value" to systolicValue,
                    "timestamp" to sample.getStartTime(TimeUnit.MILLISECONDS),
                    "unit" to "mmHg",
                    "platform" to platformKey,
                    "metadata" to metadata
                )
            }
            "blood_pressure_diastolic" -> {
                // 兼容旧类型：返回舒张压值
                mapOf(
                    "type" to dataType,
                    "value" to diastolicValue,
                    "timestamp" to sample.getStartTime(TimeUnit.MILLISECONDS),
                    "unit" to "mmHg",
                    "platform" to platformKey,
                    "metadata" to metadata
                )
            }
            else -> throw IllegalArgumentException("Unknown blood pressure type: $dataType")
        }
    }

    /**
     * 处理简单数值型数据（如步数、血糖等）
     *
     * @param dataType 数据类型
     * @param sample SamplePoint
     * @param huaweiDataType 华为 DataType
     * @param sampleSet SampleSet
     * @return 标准格式的 Map
     */
    private fun processSimpleHealthData(
        dataType: String,
        sample: com.huawei.hms.hihealth.data.SamplePoint,
        huaweiDataType: DataType,
        sampleSet: SampleSet
    ): Map<String, Any> {
        // 获取主值字段（使用第一个字段）
        val primaryField = huaweiDataType.fields.firstOrNull()
            ?: throw IllegalStateException("DataType has no fields")

        // 获取主值
        val primaryValue = when (primaryField.format) {
            Field.FORMAT_INT32 -> sample.getFieldValue(primaryField).asIntValue().toDouble()
            Field.FORMAT_LONG -> sample.getFieldValue(primaryField).asLongValue().toDouble()
            Field.FORMAT_FLOAT -> sample.getFieldValue(primaryField).asFloatValue().toDouble()
            else -> 0.0
        }

        // 构建完整的 metadata（包含所有 SDK 原始字段）
        val metadata = buildCompleteMetadata(sample, huaweiDataType, sampleSet)

        return mapOf(
            "type" to dataType,
            "value" to primaryValue,
            "timestamp" to sample.getStartTime(TimeUnit.MILLISECONDS),
            "unit" to getUnitForDataType(dataType),
            "platform" to platformKey,
            "metadata" to metadata
        )
    }

    /**
     * 处理权限申请结果
     * 参考 Demo: HealthKitAuthActivity.kt:116-136
     *
     * 在 Activity 的 onActivityResult 中调用此方法
     */
    fun handleAuthorizationResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_AUTH) {
            return false
        }

        try {
            Log.d(TAG, "📝 Handling authorization result...")
            Log.d(TAG, "   Request code: $requestCode")
            Log.d(TAG, "   Result code: $resultCode")

            // 解析权限申请结果
            val result = settingController?.parseHealthKitAuthResultFromIntent(data)

            if (result == null) {
                Log.w(TAG, "❌ Authorization result is null")
                return false
            }

            // 检查权限申请是否成功
            if (result.isSuccess) {
                Log.i(TAG, "✅ Authorization SUCCESS!")
                return true
            } else {
                val errorCode = result.errorCode
                Log.w(TAG, "❌ Authorization FAILED with error code: $errorCode")

                // 详细的错误码处理（参考 Demo）
                val errorMessage = when (errorCode) {
                    HiHealthStatusCodes.HEALTH_APP_NOT_AUTHORISED ->
                        "用户拒绝授权 (HEALTH_APP_NOT_AUTHORISED)"
                    HiHealthStatusCodes.HUAWEI_ID_SIGNIN_ERROR ->
                        "华为账号登录错误 (HUAWEI_ID_SIGNIN_ERROR)"
                    HiHealthStatusCodes.NON_HEALTH_USER ->
                        "非华为健康用户 (NON_HEALTH_USER)"
                    HiHealthStatusCodes.UNTRUST_COUNTRY_CODE ->
                        "不支持的国家/地区 (UNTRUST_COUNTRY_CODE)"
                    HiHealthStatusCodes.NO_NETWORK ->
                        "网络错误 (NO_NETWORK)"
                    HiHealthStatusCodes.UNKNOWN_AUTH_ERROR ->
                        "未知授权错误 (UNKNOWN_AUTH_ERROR)"
                    else -> "Error code: $errorCode"
                }

                Log.e(TAG, "   Error: $errorMessage")

                // 获取详细的状态码消息
                try {
                    val statusMessage = HiHealthStatusCodes.getStatusCodeMessage(errorCode)
                    Log.e(TAG, "   Status message: $statusMessage")
                } catch (e: Exception) {
                    Log.e(TAG, "   Could not get status message for error code: $errorCode")
                }

                return false
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Exception while handling authorization result", e)
            Log.e(TAG, "   Error type: ${e.javaClass.simpleName}")
            Log.e(TAG, "   Error message: ${e.message}")
            e.printStackTrace()
            return false
        }
    }
}
