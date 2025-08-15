package com.health.bridge.health_bridge.providers

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import kotlinx.coroutines.*
import java.time.LocalDate
import java.time.ZoneId
import kotlin.coroutines.suspendCoroutine
import kotlin.coroutines.resume

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
    }
    
    override fun isAvailable(): Boolean {
        return try {
            val packageManager = context.packageManager
            val packageInfo = packageManager.getPackageInfo(SAMSUNG_HEALTH_PACKAGE, 0)
            packageInfo.longVersionCode >= MIN_VERSION
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
            if (!isAvailable()) {
                Log.w(TAG, "Samsung Health not available")
                return@withContext false
            }
            
            healthDataStore = HealthDataService.getStore(context)
            
            // 请求权限
            if (activity != null) {
                hasPermissions = checkAndRequestPermissions(activity!!)
            } else {
                Log.w(TAG, "Activity is null, cannot request permissions")
                hasPermissions = false
            }
            
            Log.d(TAG, "Samsung Health initialized successfully, hasPermissions: $hasPermissions")
            hasPermissions
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Samsung Health", e)
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
        return readStepCountForDate(LocalDate.now())
    }
    
    override suspend fun readStepCountForDate(date: LocalDate): StepCountResult? = withContext(Dispatchers.IO) {
        try {
            val store = healthDataStore ?: return@withContext null
            
            val stepsResponse = getAggregateResult(store, date)
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
                        timestamp = date.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli(),
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
    
    override suspend fun readStepCountForDateRange(startDate: LocalDate, endDate: LocalDate): StepCountResult? {
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