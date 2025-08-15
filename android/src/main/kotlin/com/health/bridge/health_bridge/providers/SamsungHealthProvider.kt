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

/**
 * Samsung Health数据提供者实现
 * 负责Samsung Health SDK的具体集成
 */
class SamsungHealthProvider(
    private val context: Context
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
            
            // TODO: 请求权限的逻辑需要Activity实例
            // 这里需要重构权限请求机制
            hasPermissions = true // 临时设置
            
            Log.d(TAG, "Samsung Health initialized successfully")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Samsung Health", e)
            false
        }
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
}