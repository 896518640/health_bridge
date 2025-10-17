# 华为健康云侧API使用指南

## 📁 文件结构

```
lib/services/
├── huawei_health_api_models.dart    # 数据模型定义
└── huawei_health_api_service.dart   # API服务封装
```

## 📊 API接口说明

### 1️⃣ 统计接口 (dailyPolymerize)

**用途**: 按天聚合数据，查询每日统计值

**适用场景**:
- 查询最近一周每天的步数总数
- 查询某一天的血糖统计（平均值、最大最小值）
- 查询每日心率统计

**数据类型**: 使用 `.total` 或 `.statistics` 结尾的数据类型

### 2️⃣ 明细接口 (polymerize)

**用途**: 查询原始采样点的详细数据（不按天聚合）

**适用场景**:
- 查询某一天所有时段的步数增量
- 查询血糖测量的每次详细记录
- 查询心率的实时变化曲线

**数据类型**: 使用 `.delta` 或原子采样数据类型

---

## 🚀 快速开始

### 1. 创建服务实例

```dart
import 'package:example/services/huawei_health_api_service.dart';
import 'package:example/services/huawei_health_api_models.dart';

final service = HuaweiHealthApiService(
  accessToken: yourAccessToken,
  clientId: yourClientId,
);
```

### 2. 调用统计接口

#### 示例1：查询最近7天的每日步数总数

```dart
// 1. 构建请求参数
final request = DailyPolymerizeRequest(
  dataTypes: [HuaweiDataTypes.stepsTotal],  // 使用 steps.total
  startDay: '20231010',
  endDay: '20231016',
  timeZone: '+0800',
);

// 2. 调用API
try {
  final response = await service.dailyPolymerize(request);

  // 3. 处理响应
  for (final group in response.groups) {
    final date = group.date;

    for (final sampleSet in group.sampleSets) {
      for (final point in sampleSet.samplePoints) {
        // 使用扩展方法获取步数
        final steps = point.stepsValue;
        print('$date: $steps 步');
      }
    }
  }
} on HuaweiApiException catch (e) {
  print('API错误: ${e.message}');
}
```

#### 示例2：查询最近7天的血糖统计

```dart
final request = DailyPolymerizeRequest(
  dataTypes: [HuaweiDataTypes.bloodGlucoseCgmStats],  // 使用统计类型
  startDay: '20231010',
  endDay: '20231016',
  timeZone: '+0800',
);

final response = await service.dailyPolymerize(request);

// 使用扩展方法获取所有采样点
final allPoints = response.allSamplePoints;

// 按日期分组获取
final pointsByDate = response.samplePointsByDate;
pointsByDate.forEach((date, points) {
  print('$date: ${points.length} 条记录');
});
```

### 3. 调用明细接口

#### 示例1：查询今天的步数增量明细

```dart
// 1. 计算今天的时间范围
final now = DateTime.now();
final startTime = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
final endTime = now.millisecondsSinceEpoch;

// 2. 构建请求参数
final request = PolymerizeRequest(
  polymerizeWith: [
    PolymerizeWith(dataTypeName: HuaweiDataTypes.stepsDelta), // 使用 steps.delta
  ],
  startTime: startTime,
  endTime: endTime,
);

// 3. 调用API
try {
  final response = await service.polymerize(request);

  // 4. 处理响应
  int totalSteps = 0;
  int recordCount = 0;

  for (final point in response.allSamplePoints) {
    final steps = point.stepsValue;
    if (steps != null) {
      totalSteps += steps;
      recordCount++;

      print('${point.startDateTime} - ${point.endDateTime}: $steps 步');
    }
  }

  print('总计: $recordCount 条记录, $totalSteps 步');
} on HuaweiApiException catch (e) {
  print('API错误: ${e.message}');
}
```

#### 示例2：查询血糖明细

```dart
final request = PolymerizeRequest(
  polymerizeWith: [
    PolymerizeWith(dataTypeName: HuaweiDataTypes.bloodGlucoseInstantaneous),
  ],
  startTime: startTime,
  endTime: endTime,
);

final response = await service.polymerize(request);

for (final point in response.allSamplePoints) {
  final glucose = point.bloodGlucoseValue;  // 使用扩展方法
  final source = point.sampleSource;
  final type = point.measureType;

  print('${point.startDateTime}: $glucose mmol/L (来源:$source, 类型:$type)');
}
```

---

## 📝 数据类型常量

### 步数

```dart
HuaweiDataTypes.stepsTotal   // com.huawei.continuous.steps.total (统计)
HuaweiDataTypes.stepsDelta   // com.huawei.continuous.steps.delta (明细)
```

### 血糖

```dart
HuaweiDataTypes.bloodGlucoseInstantaneous  // 瞬时血糖 (明细)
HuaweiDataTypes.bloodGlucoseCgm           // CGM血糖 (明细)
HuaweiDataTypes.bloodGlucoseCgmStats      // CGM统计 (统计)
```

---

## 🔑 字段名称常量

```dart
FieldNames.steps              // 步数总数
FieldNames.stepsDelta         // 步数增量
FieldNames.bloodGlucoseLevel  // 血糖值
FieldNames.sampleSource       // 样本来源
FieldNames.measureType        // 测量类型
```

---

## 💡 高级用法

### 扩展方法

#### 1. 获取所有采样点（扁平化）

```dart
final response = await service.dailyPolymerize(request);
final allPoints = response.allSamplePoints;  // 返回 List<SamplePoint>
```

#### 2. 按日期分组

```dart
final pointsByDate = response.samplePointsByDate;  // 返回 Map<DateTime, List<SamplePoint>>
```

#### 3. 快速获取步数值

```dart
final steps = samplePoint.stepsValue;  // 自动兼容 steps 和 steps_delta
```

#### 4. 快速获取血糖数据

```dart
final glucose = samplePoint.bloodGlucoseValue;
final source = samplePoint.sampleSource;
final type = samplePoint.measureType;
```

---

## ⚠️ 注意事项

### 统计接口 (dailyPolymerize)

1. **日期格式**: 必须是 `yyyyMMdd` 格式，如 `20231010`
2. **时间间隔**: endDay 与 startDay 时间间隔不能超过 31 天
3. **数据类型**: 最多支持 20 个数据类型
4. **数据类型后缀**: 通常使用 `.total` 或 `.statistics` 结尾

### 明细接口 (polymerize)

1. **时间格式**: 使用毫秒时间戳
2. **时间范围**: 建议不超过 30 天
3. **数据类型**: 使用 `.delta` 或原子采样数据类型
4. **返回结构**: 即使不加 `groupByTime` 参数，也会返回 `group` 结构

---

## 🐛 错误处理

```dart
try {
  final response = await service.dailyPolymerize(request);
  // 处理响应
} on HuaweiApiException catch (e) {
  print('状态码: ${e.statusCode}');
  print('错误信息: ${e.message}');
  print('原始数据: ${e.data}');
} catch (e) {
  print('未知错误: $e');
}
```

---

## 📚 API对比表

| 特性 | dailyPolymerize (统计) | polymerize (明细) |
|------|----------------------|------------------|
| **URL** | `/v2/sampleSet:dailyPolymerize` | `/v2/sampleSet:polymerize` |
| **时间参数** | startDay/endDay (日期字符串) | startTime/endTime (毫秒时间戳) |
| **数据类型** | `.total` / `.statistics` | `.delta` / 原子采样类型 |
| **返回数据** | 每日聚合值 | 所有原始采样点 |
| **适用场景** | 按天统计 | 查看详细变化 |

---

## ✅ 完整示例

查看 `cloud_data_reading_page.dart` 中的实际使用案例。
