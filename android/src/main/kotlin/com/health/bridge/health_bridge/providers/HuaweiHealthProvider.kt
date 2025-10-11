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
     * - 血压 (blood_pressure_systolic, blood_pressure_diastolic)
     *
     * 注意：使用HealthDataTypes类来访问血糖和血压数据类型
     */
    private val dataTypeMapping = mapOf(
        // === 华为Health Kit 支持的3种数据类型（只读） ===

        // 步数
        "steps" to DataType.DT_CONTINUOUS_STEPS_DELTA,

        // 血糖
        "glucose" to HealthDataTypes.DT_INSTANTANEOUS_BLOOD_GLUCOSE,

        // 血压（收缩压和舒张压使用相同的DataType）
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
            "blood_pressure_systolic", "blood_pressure_diastolic" -> Scopes.HEALTHKIT_BLOODPRESSURE_READ
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
     * 参考 Demo 优化读取逻辑
     *
     * 华为 Health Kit 限制：
     * - 错误码 50059 = QUERY_TIME_EXCEED_LIMIT：单次查询不超过 31 天
     * - 错误码 50065 = HISTORY_PERMISSIONS_INSUFFICIENT：历史数据权限不足
     *
     * 注意：默认只能查询最近的数据，如果需要查询历史数据，可能需要：
     * 1. 申请特殊的历史数据权限
     * 2. 限制查询范围在允许的时间内（建议最近 7 天）
     */
    override suspend fun readHealthData(
        dataType: String,
        startDate: TimeCompat.LocalDate?,
        endDate: TimeCompat.LocalDate?,
        limit: Int?
    ): HealthDataResult? = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "📖 Reading health data: $dataType")

            // ⭐ 关键改进：在读取数据前检查权限
            if (!checkHealthAppAuthorization()) {
                Log.e(TAG, "❌ Cannot read data: Health App not authorized")
                Log.e(TAG, "   Please call requestPermissions() and wait for user to grant permission")
                return@withContext null
            }

            val huaweiDataType = dataTypeMapping[dataType]
            if (huaweiDataType == null) {
                Log.w(TAG, "⚠️ Unsupported data type: $dataType")
                return@withContext null
            }

            val now = TimeCompat.LocalDate.now()
            var start = startDate ?: now
            var end = endDate ?: now  // 默认使用今天，而不是 start

            // ⚠️ 华为限制：
            // 1. 单次查询时间范围不能超过 31 天
            // 2. 历史数据访问需要额外权限（HISTORYDATA_OPEN_WEEK/MONTH/YEAR）
            //    - WEEK: 可查询授权前7天的数据
            //    - MONTH: 可查询授权前30天的数据
            //    - YEAR: 可查询授权前1年的数据
            // 3. 如果没有申请历史数据权限，只能查询授权后的数据
            val javaStart = LocalDate.of(start.year, start.month, start.dayOfMonth)
            val javaEnd = LocalDate.of(end.year, end.month, end.dayOfMonth)
            val javaToday = LocalDate.now()

            // 计算天数差
            val daysDiff = java.time.temporal.ChronoUnit.DAYS.between(javaStart, javaEnd)
            val daysFromToday = java.time.temporal.ChronoUnit.DAYS.between(javaStart, javaToday)

            Log.d(TAG, "   Original date range: $javaStart to $javaEnd ($daysDiff days)")
            Log.d(TAG, "   Days from today: $daysFromToday")

            val actualStartTime: Long
            val actualEndTime: Long

            // 检查查询跨度限制（严格限制在30天以内，避免50059错误）
            if (daysDiff >= 30) {
                Log.w(TAG, "⚠️ Query time range ($daysDiff days) exceeds 30-day limit")
                Log.w(TAG, "   Adjusting to most recent 28 days for safety")
                val adjustedStart = javaEnd.minusDays(28)
                actualStartTime = adjustedStart.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
                actualEndTime = javaEnd.atTime(23, 59, 59, 999_000_000)
                    .atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
                start = TimeCompat.LocalDate(adjustedStart.year, adjustedStart.monthValue, adjustedStart.dayOfMonth)
                Log.d(TAG, "   Adjusted range: $adjustedStart to $javaEnd")
            } else {
                actualStartTime = javaStart.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
                actualEndTime = javaEnd.atTime(23, 59, 59, 999_000_000)
                    .atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()

                // 如果查询历史数据（7天前），给出提示
                if (daysFromToday > 7) {
                    Log.i(TAG, "   ℹ️ Querying historical data from $daysFromToday days ago")
                    Log.i(TAG, "   Make sure HEALTHKIT_HISTORYDATA_OPEN_WEEK permission is granted")
                }
            }

            // 计算实际的毫秒跨度
            val actualDaysSpan = (actualEndTime - actualStartTime) / (1000 * 60 * 60 * 24)
            Log.d(TAG, "   Actual time range: $actualStartTime - $actualEndTime ($actualDaysSpan days in milliseconds)")

            // ⭐ 关键改进：直接使用 DataType 读取，不使用 DataCollector
            val readOptions = ReadOptions.Builder()
                .read(huaweiDataType)  // 直接传 DataType
                .setTimeRange(actualStartTime, actualEndTime, TimeUnit.MILLISECONDS)
                .build()

            Log.d(TAG, "📡 Executing read request...")
            val readReply = suspendCoroutine<com.huawei.hms.hihealth.result.ReadReply> { continuation ->
                dataController!!.read(readOptions)
                    .addOnSuccessListener {
                        Log.d(TAG, "✅ Read success for $dataType, sampleSets: ${it.sampleSets.size}")
                        continuation.resume(it)
                    }
                    .addOnFailureListener { e ->
                        Log.e(TAG, "❌ Read failed for $dataType: ${e.message}", e)
                        continuation.resumeWithException(e)
                    }
            }

            val dataList = mutableListOf<Map<String, Any>>()
            val field = fieldMapping[dataType]

            if (field == null) {
                Log.w(TAG, "⚠️ 数据类型 $dataType 没有预定义的字段映射，将从 DataType 中动态获取")

                // 打印 DataType 的所有可用字段
                Log.d(TAG, "📋 DataType '${huaweiDataType.name}' 包含 ${huaweiDataType.fields.size} 个字段:")
                huaweiDataType.fields.forEachIndexed { index, f ->
                    Log.d(TAG, "   字段[$index]: name='${f.name}', format=${f.format}")
                }

                // 特殊处理：血压数据包含收缩压和舒张压两个字段
                if (dataType == "blood_pressure_systolic" || dataType == "blood_pressure_diastolic") {
                    Log.d(TAG, "🩺 血压数据特殊处理...")
                    Log.d(TAG, "   请求的数据类型: $dataType")

                    // 查找收缩压和舒张压字段
                    // 华为SDK中，字段名可能是 "systolic" 和 "diastolic" 或类似名称
                    val systolicField = huaweiDataType.fields.find {
                        it.name.contains("systolic", ignoreCase = true) ||
                        it.name.contains("sbp", ignoreCase = true) ||
                        it.name.contains("收缩", ignoreCase = true)
                    }
                    val diastolicField = huaweiDataType.fields.find {
                        it.name.contains("diastolic", ignoreCase = true) ||
                        it.name.contains("dbp", ignoreCase = true) ||
                        it.name.contains("舒张", ignoreCase = true)
                    }

                    Log.d(TAG, "   找到收缩压字段: ${systolicField?.name ?: "未找到"}")
                    Log.d(TAG, "   找到舒张压字段: ${diastolicField?.name ?: "未找到"}")

                    // 根据请求的类型选择对应的字段
                    val targetField = if (dataType == "blood_pressure_systolic") {
                        systolicField
                    } else {
                        diastolicField
                    }

                    if (targetField == null) {
                        Log.e(TAG, "❌ 无法找到对应的血压字段!")
                        return@withContext null
                    }

                    Log.d(TAG, "✅ 使用字段: ${targetField.name}")
                    Log.d(TAG, "🔍 处理 ${readReply.sampleSets.size} 个 SampleSet...")

                    for (sampleSet in readReply.sampleSets) {
                        Log.d(TAG, "   📦 SampleSet 包含 ${sampleSet.samplePoints.size} 个数据点")
                        for (sample in sampleSet.samplePoints) {
                            // 打印 SamplePoint 的完整元数据
                            Log.d(TAG, "   ═══════════════════════════════════════")
                            Log.d(TAG, "   📊 SamplePoint 元数据:")
                            Log.d(TAG, "      DataType: ${sample.dataType.name}")
                            Log.d(TAG, "      开始时间: ${sample.getStartTime(TimeUnit.MILLISECONDS)}")
                            Log.d(TAG, "      结束时间: ${sample.getEndTime(TimeUnit.MILLISECONDS)}")
                            Log.d(TAG, "      采样时间: ${sample.getSamplingTime(TimeUnit.MILLISECONDS)}")

                            // 打印所有字段的值
                            Log.d(TAG, "      所有字段值:")
                            huaweiDataType.fields.forEach { field ->
                                try {
                                    val fieldValue = when (field.format) {
                                        Field.FORMAT_INT32 -> sample.getFieldValue(field).asIntValue()
                                        Field.FORMAT_LONG -> sample.getFieldValue(field).asLongValue()
                                        Field.FORMAT_FLOAT -> sample.getFieldValue(field).asFloatValue()
                                        Field.FORMAT_STRING -> {
                                            try {
                                                sample.getFieldValue(field).asStringValue()
                                            } catch (e: Exception) {
                                                "<无数据>"
                                            }
                                        }
                                        else -> "<未知格式:${field.format}>"
                                    }
                                    Log.d(TAG, "         ${field.name} = $fieldValue (format=${field.format})")
                                } catch (e: Exception) {
                                    Log.d(TAG, "         ${field.name} = <无数据> (${e.message})")
                                }
                            }

                            // 打印 SampleSet 的 DataCollector 信息
                            try {
                                Log.d(TAG, "      DataCollector 信息:")
                                val collector = sampleSet.dataCollector
                                if (collector != null) {
                                    Log.d(TAG, "         DataType: ${collector.dataType?.name ?: "N/A"}")
                                    Log.d(TAG, "         DataStreamName: ${collector.dataStreamName ?: "N/A"}")
                                } else {
                                    Log.d(TAG, "         DataCollector: null")
                                }
                            } catch (e: Exception) {
                                Log.d(TAG, "      DataCollector 信息读取失败: ${e.message}")
                            }
                            Log.d(TAG, "   ═══════════════════════════════════════")

                            val value = when (targetField.format) {
                                Field.FORMAT_INT32 -> sample.getFieldValue(targetField).asIntValue().toDouble()
                                Field.FORMAT_LONG -> sample.getFieldValue(targetField).asLongValue().toDouble()
                                Field.FORMAT_FLOAT -> sample.getFieldValue(targetField).asFloatValue().toDouble()
                                else -> 0.0
                            }

                            val timestamp = sample.getStartTime(TimeUnit.MILLISECONDS)
                            Log.d(TAG, "   📍 数据点: 值=$value ${getUnitForDataType(dataType)}, 时间戳=$timestamp")

                            // 如果是血压数据，额外打印另一个字段的值用于调试
                            if (dataType == "blood_pressure_systolic" && diastolicField != null) {
                                val diastolicValue = when (diastolicField.format) {
                                    Field.FORMAT_INT32 -> sample.getFieldValue(diastolicField).asIntValue().toDouble()
                                    Field.FORMAT_LONG -> sample.getFieldValue(diastolicField).asLongValue().toDouble()
                                    Field.FORMAT_FLOAT -> sample.getFieldValue(diastolicField).asFloatValue().toDouble()
                                    else -> 0.0
                                }
                                Log.d(TAG, "      (同一记录的舒张压值: $diastolicValue mmHg)")
                            } else if (dataType == "blood_pressure_diastolic" && systolicField != null) {
                                val systolicValue = when (systolicField.format) {
                                    Field.FORMAT_INT32 -> sample.getFieldValue(systolicField).asIntValue().toDouble()
                                    Field.FORMAT_LONG -> sample.getFieldValue(systolicField).asLongValue().toDouble()
                                    Field.FORMAT_FLOAT -> sample.getFieldValue(systolicField).asFloatValue().toDouble()
                                    else -> 0.0
                                }
                                Log.d(TAG, "      (同一记录的收缩压值: $systolicValue mmHg)")
                            }

                            dataList.add(
                                mapOf(
                                    "type" to dataType,
                                    "value" to value,
                                    "timestamp" to timestamp,
                                    "unit" to getUnitForDataType(dataType),
                                    "platform" to platformKey
                                )
                            )

                            if (limit != null && dataList.size >= limit) break
                        }
                        if (limit != null && dataList.size >= limit) break
                    }
                } else {
                    // 其他数据类型：使用第一个字段
                    val defaultField = huaweiDataType.fields.firstOrNull()
                    if (defaultField == null) {
                        Log.e(TAG, "❌ DataType 没有可用字段!")
                        return@withContext null
                    }

                    Log.d(TAG, "✅ 使用默认字段: ${defaultField.name}")
                    Log.d(TAG, "🔍 处理 ${readReply.sampleSets.size} 个 SampleSet...")

                    for (sampleSet in readReply.sampleSets) {
                        Log.d(TAG, "   📦 SampleSet 包含 ${sampleSet.samplePoints.size} 个数据点")
                        for (sample in sampleSet.samplePoints) {
                            val value = when (defaultField.format) {
                                Field.FORMAT_INT32 -> sample.getFieldValue(defaultField).asIntValue().toDouble()
                                Field.FORMAT_LONG -> sample.getFieldValue(defaultField).asLongValue().toDouble()
                                Field.FORMAT_FLOAT -> sample.getFieldValue(defaultField).asFloatValue().toDouble()
                                Field.FORMAT_STRING -> 0.0  // String 类型暂不支持
                                Field.FORMAT_MAP -> 0.0  // Map 类型暂不支持
                                else -> 0.0
                            }

                            val timestamp = sample.getStartTime(TimeUnit.MILLISECONDS)
                            Log.d(TAG, "   📍 数据点: 值=$value ${getUnitForDataType(dataType)}, 时间戳=$timestamp")

                            dataList.add(
                                mapOf(
                                    "type" to dataType,
                                    "value" to value,
                                    "timestamp" to timestamp,
                                    "unit" to getUnitForDataType(dataType),
                                    "platform" to platformKey
                                )
                            )

                            if (limit != null && dataList.size >= limit) break
                        }
                        if (limit != null && dataList.size >= limit) break
                    }
                }
            } else {
                Log.d(TAG, "🔍 Processing ${readReply.sampleSets.size} sampleSets with field: ${field.name}...")
                for (sampleSet in readReply.sampleSets) {
                    Log.d(TAG, "   SampleSet has ${sampleSet.samplePoints.size} points")
                    for (sample in sampleSet.samplePoints) {
                        // TODO: 血压数据特殊处理 - 暂时注释,因为Field常量不存在
                        /*
                        // ⭐ 特殊处理：血压数据包含收缩压和舒张压两个值
                        if (dataType == "systolic_blood_pressure" || dataType == "diastolic_blood_pressure") {
                            ...
                        } else {
                        */
                            // 其他数据类型的正常处理
                            val value = when (field.format) {
                                Field.FORMAT_INT32 -> sample.getFieldValue(field).asIntValue().toDouble()
                                Field.FORMAT_LONG -> sample.getFieldValue(field).asLongValue().toDouble()
                                Field.FORMAT_FLOAT -> sample.getFieldValue(field).asFloatValue().toDouble()
                                else -> 0.0
                            }

                            Log.d(TAG, "   📍 Value: $value at ${sample.getStartTime(TimeUnit.MILLISECONDS)}")

                            dataList.add(
                                mapOf(
                                    "type" to dataType,
                                    "value" to value,
                                    "timestamp" to sample.getStartTime(TimeUnit.MILLISECONDS),
                                    "unit" to getUnitForDataType(dataType),
                                    "platform" to platformKey
                                )
                            )
                        // }

                        if (limit != null && dataList.size >= limit) break
                    }
                    if (limit != null && dataList.size >= limit) break
                }
            }

            Log.d(TAG, "✅ Successfully read ${dataList.size} data points for $dataType")

            HealthDataResult(
                data = dataList,
                dataSource = "huawei_health_kit",
                metadata = mapOf(
                    "count" to dataList.size,
                    "dataType" to dataType,
                    "startDate" to start.toString(),
                    "endDate" to end.toString()
                )
            )
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error reading health data for $dataType", e)
            Log.e(TAG, "   Error type: ${e.javaClass.simpleName}")
            Log.e(TAG, "   Error message: ${e.message}")
            e.printStackTrace()
            null
        }
    }

    /**
     * 写入健康数据
     * 注意：华为Health Kit不支持写入操作，直接返回false
     */
    override suspend fun writeHealthData(dataMap: Map<String, Any>): Boolean = withContext(Dispatchers.IO) {
        Log.w(TAG, "⚠️ Huawei Health Kit does not support write operations")
        return@withContext false
    }

    /**
     * 批量写入健康数据
     * 注意：华为Health Kit不支持写入操作，直接返回false
     */
    override suspend fun writeBatchHealthData(dataList: List<Map<String, Any>>): Boolean {
        Log.w(TAG, "⚠️ Huawei Health Kit does not support write operations")
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
        Log.d(TAG, "Huawei Health Kit cleaned up")
    }

    /**
     * 获取数据类型对应的单位
     */
    private fun getUnitForDataType(dataType: String): String {
        return when (dataType) {
            "steps" -> "steps"
            "glucose" -> "mmol/L"
            "blood_pressure_systolic", "blood_pressure_diastolic" -> "mmHg"
            else -> ""
        }
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
