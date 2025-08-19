package com.health.bridge.health_bridge.utils

import android.os.Build
import java.util.*
import java.time.LocalDate as JavaLocalDate
import java.time.ZoneId as JavaZoneId
import java.time.Instant as JavaInstant

/**
 * 时间API兼容层 - 支持API 21+
 * 在API 26+使用java.time，API 21-25使用传统Calendar
 */
object TimeCompat {
    
    /**
     * 兼容的LocalDate实现
     */
    data class LocalDate(
        val year: Int,
        val month: Int,
        val dayOfMonth: Int
    ) {
        companion object {
            fun now(): LocalDate {
                return if (Build.VERSION.SDK_INT >= 26) {
                    val javaDate = JavaLocalDate.now()
                    LocalDate(javaDate.year, javaDate.monthValue, javaDate.dayOfMonth)
                } else {
                    val calendar = Calendar.getInstance()
                    LocalDate(
                        calendar.get(Calendar.YEAR),
                        calendar.get(Calendar.MONTH) + 1, // Calendar.MONTH 是0-11
                        calendar.get(Calendar.DAY_OF_MONTH)
                    )
                }
            }
        }
        
        fun plusDays(days: Long): LocalDate {
            return if (Build.VERSION.SDK_INT >= 26) {
                val javaDate = JavaLocalDate.of(year, month, dayOfMonth).plusDays(days)
                LocalDate(javaDate.year, javaDate.monthValue, javaDate.dayOfMonth)
            } else {
                val calendar = Calendar.getInstance()
                calendar.set(year, month - 1, dayOfMonth) // Calendar.MONTH 是0-11
                calendar.add(Calendar.DAY_OF_MONTH, days.toInt())
                LocalDate(
                    calendar.get(Calendar.YEAR),
                    calendar.get(Calendar.MONTH) + 1,
                    calendar.get(Calendar.DAY_OF_MONTH)
                )
            }
        }
        
        fun isAfter(other: LocalDate): Boolean {
            return when {
                year != other.year -> year > other.year
                month != other.month -> month > other.month
                else -> dayOfMonth > other.dayOfMonth
            }
        }
        
        fun atStartOfDay(): Long {
            return if (Build.VERSION.SDK_INT >= 26) {
                JavaLocalDate.of(year, month, dayOfMonth)
                    .atStartOfDay(JavaZoneId.systemDefault())
                    .toEpochSecond() * 1000
            } else {
                val calendar = Calendar.getInstance()
                calendar.set(year, month - 1, dayOfMonth, 0, 0, 0)
                calendar.set(Calendar.MILLISECOND, 0)
                calendar.timeInMillis
            }
        }
        
        override fun toString(): String = "$year-${month.toString().padStart(2, '0')}-${dayOfMonth.toString().padStart(2, '0')}"
    }
    
    /**
     * 毫秒转LocalDate
     */
    fun millisToLocalDate(millis: Long): LocalDate {
        return if (Build.VERSION.SDK_INT >= 26) {
            val javaDate = JavaInstant.ofEpochMilli(millis)
                .atZone(JavaZoneId.systemDefault())
                .toLocalDate()
            LocalDate(javaDate.year, javaDate.monthValue, javaDate.dayOfMonth)
        } else {
            val calendar = Calendar.getInstance()
            calendar.timeInMillis = millis
            LocalDate(
                calendar.get(Calendar.YEAR),
                calendar.get(Calendar.MONTH) + 1,
                calendar.get(Calendar.DAY_OF_MONTH)
            )
        }
    }
}