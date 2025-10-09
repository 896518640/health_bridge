import Foundation
import HealthKit

// MARK: - Health Data Units
private struct HealthUnits {
    static let bloodGlucose = HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.literUnit(with: .deci))
    static let kilogram = HKUnit.gramUnit(with: .kilo)
    static let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())
    static let mmHg = HKUnit.millimeterOfMercury()
    static let kilocalorie = HKUnit.kilocalorie()
    static let count = HKUnit.count()
}

// MARK: - Health Data Types
private struct HealthDataTypes {
    static let glucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!
    static let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    static let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    static let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    static let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
    static let heightType = HKQuantityType.quantityType(forIdentifier: .height)!
    static let systolicBloodPressureType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)!
    static let diastolicBloodPressureType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)!
    static let bodyTemperatureType = HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!
    static let oxygenSaturationType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
}

// MARK: - Configuration
private struct HealthManagerConfig {
    static let maxQueryTimeout: TimeInterval = 30
    static let defaultQueryLimit = 1000
    static let appSource = "Health Bridge App"
}

class AppleHealthManager {
    private let healthStore = HKHealthStore()
    private var activeQueries: Set<HKQuery> = []
    
    private var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    // MARK: - Initialization
    func initialize(completion: @escaping (Bool, String?) -> Void) {
        guard isHealthKitAvailable else {
            completion(false, "HealthKit is not available on this device")
            return
        }
        
        let readTypes = createReadTypes()
        let writeTypes = createWriteTypes()
        
        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription)
            }
        }
    }
    
    private func createReadTypes() -> Set<HKObjectType> {
        return [
            HealthDataTypes.glucoseType,
            HealthDataTypes.stepCountType,
            HealthDataTypes.activeEnergyType,
            HealthDataTypes.heartRateType,
            HealthDataTypes.bodyMassType,
            HealthDataTypes.heightType,
            HealthDataTypes.systolicBloodPressureType,
            HealthDataTypes.diastolicBloodPressureType,
            HealthDataTypes.bodyTemperatureType,
            HealthDataTypes.oxygenSaturationType
        ]
    }
    
    private func createWriteTypes() -> Set<HKSampleType> {
        return [
            HealthDataTypes.glucoseType,
            HealthDataTypes.bodyMassType,
            HealthDataTypes.systolicBloodPressureType,
            HealthDataTypes.diastolicBloodPressureType,
            HealthDataTypes.bodyTemperatureType
        ]
    }
    
    // MARK: - Glucose Data Management
    func insertGlucoseData(value: Double, date: Date, completion: @escaping (Bool, String?) -> Void) {
        guard isHealthKitAvailable else {
            completion(false, "HealthKit is not available")
            return
        }
        
        let glucoseQuantity = HKQuantity(unit: HealthUnits.bloodGlucose, doubleValue: value)
        let metadata: [String: Any] = [
            HKMetadataKeyWasUserEntered: true,
            "source": HealthManagerConfig.appSource
        ]
        
        let glucoseSample = HKQuantitySample(
            type: HealthDataTypes.glucoseType,
            quantity: glucoseQuantity,
            start: date,
            end: date,
            metadata: metadata
        )
        
        saveHealthData(glucoseSample, completion: completion)
    }
    
    func readGlucoseData(from startDate: Date, to endDate: Date, completion: @escaping ([[String: Any]], String?) -> Void) {
        guard isHealthKitAvailable else {
            completion([], "HealthKit is not available")
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(
            sampleType: HealthDataTypes.glucoseType,
            predicate: predicate,
            limit: HealthManagerConfig.defaultQueryLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion([], error.localizedDescription)
                    return
                }
                
                let glucoseData = (samples as? [HKQuantitySample])?.map { sample in
                    self?.createGlucoseDataDictionary(from: sample) ?? [:]
                } ?? []
                
                completion(glucoseData, nil)
            }
        }
        
        executeQuery(query)
    }
    
    private func createGlucoseDataDictionary(from sample: HKQuantitySample) -> [String: Any] {
        let value = sample.quantity.doubleValue(for: HealthUnits.bloodGlucose)
        let timestamp = Int64(sample.startDate.timeIntervalSince1970 * 1000)
        
        return [
            "value": value,
            "timestamp": timestamp,
            "unit": "mg/dL",
            "source": sample.sourceRevision.source.name
        ]
    }
    
    // MARK: - Step Count Management
    func readTodayStepCount(completion: @escaping ([String: Any], String?) -> Void) {
        guard isHealthKitAvailable else {
            completion([:], "HealthKit is not available")
            return
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        readStepCount(from: startOfDay, to: endOfDay) { [weak self] stepData, error in
            if let error = error {
                completion([:], error)
                return
            }
            
            self?.readActiveEnergy(from: startOfDay, to: endOfDay) { calories, _ in
                let result: [String: Any] = [
                    "totalSteps": stepData["totalSteps"] as? Int ?? 0,
                    "totalCalories": calories,
                    "data": stepData["data"] as? [[String: Any]] ?? []
                ]
                completion(result, nil)
            }
        }
    }
    
    func getStepCount(startDate: Date, endDate: Date, completion: @escaping (Double) -> Void) {
        guard isHealthKitAvailable else {
            completion(0.0)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: HealthDataTypes.stepCountType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, statistics, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error reading step count: \(error.localizedDescription)")
                    completion(0.0)
                    return
                }
                
                let steps = statistics?.sumQuantity()?.doubleValue(for: HealthUnits.count) ?? 0.0
                completion(steps)
            }
        }
        
        executeQuery(query)
    }
    
    private func readStepCount(from startDate: Date, to endDate: Date, completion: @escaping ([String: Any], String?) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let interval = DateComponents(hour: 1)
        
        let query = HKStatisticsCollectionQuery(
            quantityType: HealthDataTypes.stepCountType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { [weak self] _, collection, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion([:], error.localizedDescription)
                    return
                }
                
                let result = self?.processStepCountCollection(collection, from: startDate, to: endDate) ?? [:]
                completion(result, nil)
            }
        }
        
        executeQuery(query)
    }
    
    private func processStepCountCollection(_ collection: HKStatisticsCollection?, from startDate: Date, to endDate: Date) -> [String: Any] {
        guard let collection = collection else {
            return [:]
        }
        
        var totalSteps = 0
        var hourlyData: [[String: Any]] = []
        
        collection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
            if let sum = statistics.sumQuantity() {
                let steps = Int(sum.doubleValue(for: HealthUnits.count))
                totalSteps += steps
                
                let timestamp = Int64(statistics.startDate.timeIntervalSince1970 * 1000)
                hourlyData.append([
                    "type": "steps",
                    "value": steps,
                    "timestamp": timestamp,
                    "unit": "steps",
                    "platform": "apple_health"
                ])
            }
        }
        
        return [
            "totalSteps": totalSteps,
            "data": hourlyData
        ]
    }
    
    private func readActiveEnergy(from startDate: Date, to endDate: Date, completion: @escaping (Double, String?) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: HealthDataTypes.activeEnergyType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, statistics, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(0.0, error.localizedDescription)
                    return
                }
                
                let calories = statistics?.sumQuantity()?.doubleValue(for: HealthUnits.kilocalorie) ?? 0.0
                completion(calories, nil)
            }
        }
        
        executeQuery(query)
    }
    
    // MARK: - Heart Rate Management
    func readHeartRate(from startDate: Date, to endDate: Date, completion: @escaping ([[String: Any]], String?) -> Void) {
        guard isHealthKitAvailable else {
            completion([], "HealthKit is not available")
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(
            sampleType: HealthDataTypes.heartRateType,
            predicate: predicate,
            limit: HealthManagerConfig.defaultQueryLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion([], error.localizedDescription)
                    return
                }
                
                let heartRateData: [[String: Any]] = (samples as? [HKQuantitySample])?.map { sample in
                    let value = sample.quantity.doubleValue(for: HealthUnits.beatsPerMinute)
                    let timestamp = Int64(sample.startDate.timeIntervalSince1970 * 1000)
                    
                    return [
                        "value": value,
                        "timestamp": timestamp,
                        "unit": "bpm",
                        "type": "heart_rate",
                        "source": sample.sourceRevision.source.name
                    ] as [String: Any]
                } ?? []
                
                completion(heartRateData, nil)
            }
        }
        
        executeQuery(query)
    }
    
    // MARK: - Body Mass (Weight) Management
    func insertBodyMass(value: Double, date: Date, completion: @escaping (Bool, String?) -> Void) {
        guard isHealthKitAvailable else {
            completion(false, "HealthKit is not available")
            return
        }
        
        let massQuantity = HKQuantity(unit: HealthUnits.kilogram, doubleValue: value)
        let metadata: [String: Any] = [
            HKMetadataKeyWasUserEntered: true,
            "source": HealthManagerConfig.appSource
        ]
        
        let massSample = HKQuantitySample(
            type: HealthDataTypes.bodyMassType,
            quantity: massQuantity,
            start: date,
            end: date,
            metadata: metadata
        )
        
        saveHealthData(massSample, completion: completion)
    }
    
    func readBodyMass(from startDate: Date, to endDate: Date, completion: @escaping ([[String: Any]], String?) -> Void) {
        guard isHealthKitAvailable else {
            completion([], "HealthKit is not available")
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(
            sampleType: HealthDataTypes.bodyMassType,
            predicate: predicate,
            limit: HealthManagerConfig.defaultQueryLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion([], error.localizedDescription)
                    return
                }
                
                let massData: [[String: Any]] = (samples as? [HKQuantitySample])?.map { sample in
                    let value = sample.quantity.doubleValue(for: HealthUnits.kilogram)
                    let timestamp = Int64(sample.startDate.timeIntervalSince1970 * 1000)
                    
                    return [
                        "value": value,
                        "timestamp": timestamp,
                        "unit": "kg",
                        "type": "body_mass",
                        "source": sample.sourceRevision.source.name
                    ] as [String: Any]
                } ?? []
                
                completion(massData, nil)
            }
        }
        
        executeQuery(query)
    }
    
    // MARK: - Blood Pressure Management
    func insertBloodPressure(systolic: Double, diastolic: Double, date: Date, completion: @escaping (Bool, String?) -> Void) {
        guard isHealthKitAvailable else {
            completion(false, "HealthKit is not available")
            return
        }
        
        let systolicQuantity = HKQuantity(unit: HealthUnits.mmHg, doubleValue: systolic)
        let diastolicQuantity = HKQuantity(unit: HealthUnits.mmHg, doubleValue: diastolic)
        
        let metadata: [String: Any] = [
            HKMetadataKeyWasUserEntered: true,
            "source": HealthManagerConfig.appSource
        ]
        
        let systolicSample = HKQuantitySample(
            type: HealthDataTypes.systolicBloodPressureType,
            quantity: systolicQuantity,
            start: date,
            end: date,
            metadata: metadata
        )
        
        let diastolicSample = HKQuantitySample(
            type: HealthDataTypes.diastolicBloodPressureType,
            quantity: diastolicQuantity,
            start: date,
            end: date,
            metadata: metadata
        )
        
        healthStore.save([systolicSample, diastolicSample]) { success, error in
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription)
            }
        }
    }
    
    // MARK: - Query Management
    private func executeQuery(_ query: HKQuery) {
        activeQueries.insert(query)
        healthStore.execute(query)
        
        // 自动清理超时的查询
        DispatchQueue.main.asyncAfter(deadline: .now() + HealthManagerConfig.maxQueryTimeout) { [weak self] in
            self?.activeQueries.remove(query)
        }
    }
    
    // MARK: - Helper Methods
    private func saveHealthData(_ sample: HKSample, completion: @escaping (Bool, String?) -> Void) {
        healthStore.save(sample) { success, error in
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription)
            }
        }
    }
    
    // MARK: - Permission Management

    /// 检查指定数据类型的权限状态
    func checkPermissions(for dataTypes: [String], operation: String, completion: @escaping ([String: String]) -> Void) {
        guard isHealthKitAvailable else {
            completion([:])
            return
        }

        var permissionStatus: [String: String] = [:]

        for dataTypeKey in dataTypes {
            var objectType: HKObjectType? = nil

            // Handle workout type
            if dataTypeKey == "workout" {
                objectType = HKWorkoutType.workoutType()
            }
            // Handle sleep types
            else if dataTypeKey.hasPrefix("sleep_") {
                objectType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
            }
            // Handle quantity types
            else {
                objectType = getQuantityType(for: dataTypeKey)
            }

            if let type = objectType {
                let status: HKAuthorizationStatus

                if operation == "write" {
                    status = healthStore.authorizationStatus(for: type)
                } else {
                    // HealthKit 不允许检查读取权限状态，总是返回 notDetermined
                    status = .notDetermined
                }

                permissionStatus[dataTypeKey] = convertAuthorizationStatus(status)
            }
        }

        completion(permissionStatus)
    }

    /// 申请指定数据类型的权限
    func requestPermissions(for dataTypes: [String], operations: [String], completion: @escaping (Bool, String?) -> Void) {
        guard isHealthKitAvailable else {
            completion(false, "HealthKit is not available on this device")
            return
        }

        var readTypes: Set<HKObjectType> = []
        var writeTypes: Set<HKSampleType> = []

        let needsRead = operations.contains("read")
        let needsWrite = operations.contains("write")

        for dataTypeKey in dataTypes {
            // Handle workout type separately (HKWorkoutType instead of HKQuantityType)
            if dataTypeKey == "workout" {
                if needsRead {
                    readTypes.insert(HKWorkoutType.workoutType())
                }
                // Workout is read-only, cannot write
                continue
            }

            // Handle sleep analysis separately (HKCategoryType instead of HKQuantityType)
            if dataTypeKey.hasPrefix("sleep_") {
                if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
                    if needsRead {
                        readTypes.insert(sleepType)
                    }
                    if needsWrite {
                        writeTypes.insert(sleepType)
                    }
                }
                continue
            }

            // Handle quantity types
            if let quantityType = getQuantityType(for: dataTypeKey) {
                if needsRead {
                    readTypes.insert(quantityType)
                }
                if needsWrite && canWriteDataType(dataTypeKey) {
                    writeTypes.insert(quantityType)
                }
            }
        }

        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
            DispatchQueue.main.async {
                completion(success, error?.localizedDescription)
            }
        }
    }

    private func convertAuthorizationStatus(_ status: HKAuthorizationStatus) -> String {
        switch status {
        case .sharingAuthorized:
            return "granted"
        case .sharingDenied:
            return "denied"
        case .notDetermined:
            return "not_determined"
        @unknown default:
            return "not_determined"
        }
    }

    private func canWriteDataType(_ dataTypeKey: String) -> Bool {
        // 定义哪些数据类型支持写入
        let writableTypes = [
            "glucose", "weight", "height", "body_fat",
            "blood_pressure_systolic", "blood_pressure_diastolic",
            "body_temperature", "oxygen_saturation"
        ]
        return writableTypes.contains(dataTypeKey)
    }

    // MARK: - Platform Capability Query

    /// 获取平台支持的数据类型列表
    func getSupportedDataTypes() -> [String] {
        return [
            "steps", "distance", "active_calories",
            "glucose",
            "heart_rate", "blood_pressure_systolic", "blood_pressure_diastolic",
            "weight", "height", "body_fat", "bmi",
            "sleep_duration", "sleep_deep", "sleep_light", "sleep_rem",
            "water",
            "workout",
            "oxygen_saturation", "body_temperature", "respiratory_rate"
        ]
    }

    /// 检查是否支持某个数据类型
    func isDataTypeSupported(_ dataTypeKey: String, operation: String) -> Bool {
        let supportedTypes = getSupportedDataTypes()

        if !supportedTypes.contains(dataTypeKey) {
            return false
        }

        // 检查是否支持写入
        if operation == "write" {
            return canWriteDataType(dataTypeKey)
        }

        return true
    }

    // MARK: - Universal Data Read/Write

    /// 通用数据读取方法
    func readHealthData(
        dataType: String,
        startDate: Date?,
        endDate: Date?,
        limit: Int?,
        completion: @escaping ([[String: Any]], String?) -> Void
    ) {
        guard isHealthKitAvailable else {
            completion([], "HealthKit is not available")
            return
        }

        let now = Date()
        let start = startDate ?? Calendar.current.startOfDay(for: now)
        let end = endDate ?? now
        let queryLimit = limit ?? HealthManagerConfig.defaultQueryLimit

        // Handle workout type separately
        if dataType == "workout" {
            readWorkoutData(from: start, to: end, limit: queryLimit, completion: completion)
            return
        }

        // Handle sleep types separately
        if dataType.hasPrefix("sleep_") {
            readSleepData(sleepType: dataType, from: start, to: end, limit: queryLimit, completion: completion)
            return
        }

        // Handle quantity types
        guard let quantityType = getQuantityType(for: dataType) else {
            completion([], "Unsupported data type: \(dataType)")
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(
            sampleType: quantityType,
            predicate: predicate,
            limit: queryLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion([], error.localizedDescription)
                    return
                }

                let data = (samples as? [HKQuantitySample])?.map { sample in
                    self.createDataDictionary(from: sample, dataType: dataType)
                } ?? []

                completion(data, nil)
            }
        }

        executeQuery(query)
    }

    /// 读取 Workout 数据
    private func readWorkoutData(
        from startDate: Date,
        to endDate: Date,
        limit: Int,
        completion: @escaping ([[String: Any]], String?) -> Void
    ) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(
            sampleType: HKWorkoutType.workoutType(),
            predicate: predicate,
            limit: limit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion([], error.localizedDescription)
                    return
                }

                let workoutData = (samples as? [HKWorkout])?.map { workout in
                    self.createWorkoutDataDictionary(from: workout)
                } ?? []

                completion(workoutData, nil)
            }
        }

        executeQuery(query)
    }

    /// 读取睡眠数据
    private func readSleepData(
        sleepType: String,
        from startDate: Date,
        to endDate: Date,
        limit: Int,
        completion: @escaping ([[String: Any]], String?) -> Void
    ) {
        guard let categoryType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion([], "Sleep analysis type not available")
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(
            sampleType: categoryType,
            predicate: predicate,
            limit: limit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion([], error.localizedDescription)
                    return
                }

                let sleepData = (samples as? [HKCategorySample])?.compactMap { sample in
                    self.createSleepDataDictionary(from: sample, sleepType: sleepType)
                } ?? []

                completion(sleepData, nil)
            }
        }

        executeQuery(query)
    }

    /// 创建 Workout 数据字典
    private func createWorkoutDataDictionary(from workout: HKWorkout) -> [String: Any] {
        let timestamp = Int64(workout.startDate.timeIntervalSince1970 * 1000)
        let duration = workout.duration / 60.0 // Convert to minutes

        var workoutTypeName = "Unknown"
        if #available(iOS 10.0, *) {
            switch workout.workoutActivityType {
            case .running: workoutTypeName = "Running"
            case .walking: workoutTypeName = "Walking"
            case .cycling: workoutTypeName = "Cycling"
            case .swimming: workoutTypeName = "Swimming"
            case .yoga: workoutTypeName = "Yoga"
            case .functionalStrengthTraining: workoutTypeName = "Strength Training"
            case .traditionalStrengthTraining: workoutTypeName = "Weight Training"
            case .crossTraining: workoutTypeName = "Cross Training"
            case .mixedCardio: workoutTypeName = "Cardio"
            case .highIntensityIntervalTraining: workoutTypeName = "HIIT"
            case .elliptical: workoutTypeName = "Elliptical"
            case .stairClimbing: workoutTypeName = "Stair Climbing"
            case .rowing: workoutTypeName = "Rowing"
            default: workoutTypeName = "Other"
            }
        }

        var result: [String: Any] = [
            "type": "workout",
            "value": duration,
            "timestamp": timestamp,
            "unit": "minutes",
            "platform": "apple_health",
            "source": workout.sourceRevision.source.name,
            "workout_type": workoutTypeName
        ]

        // Add optional fields
        if let totalDistance = workout.totalDistance {
            result["distance"] = totalDistance.doubleValue(for: .meter())
            result["distance_unit"] = "meters"
        }

        if let totalEnergy = workout.totalEnergyBurned {
            result["calories"] = totalEnergy.doubleValue(for: .kilocalorie())
            result["calories_unit"] = "kcal"
        }

        return result
    }

    /// 创建睡眠数据字典
    private func createSleepDataDictionary(from sample: HKCategorySample, sleepType: String) -> [String: Any]? {
        let timestamp = Int64(sample.startDate.timeIntervalSince1970 * 1000)
        let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0 // Convert to minutes

        // Map HKCategoryValueSleepAnalysis to our sleep types
        var matchesSleepType = false
        var sleepStageName = ""

        if #available(iOS 16.0, *) {
            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                matchesSleepType = (sleepType == "sleep_light")
                sleepStageName = "Light Sleep"
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                matchesSleepType = (sleepType == "sleep_deep")
                sleepStageName = "Deep Sleep"
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                matchesSleepType = (sleepType == "sleep_rem")
                sleepStageName = "REM Sleep"
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                 HKCategoryValueSleepAnalysis.asleep.rawValue:
                matchesSleepType = (sleepType == "sleep_duration")
                sleepStageName = "Asleep"
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                matchesSleepType = (sleepType == "sleep_duration")
                sleepStageName = "Awake"
            case HKCategoryValueSleepAnalysis.inBed.rawValue:
                matchesSleepType = (sleepType == "sleep_duration")
                sleepStageName = "In Bed"
            default:
                return nil
            }
        } else {
            // For iOS < 16, only basic sleep analysis is available
            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleep.rawValue:
                matchesSleepType = (sleepType == "sleep_duration")
                sleepStageName = "Asleep"
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                matchesSleepType = (sleepType == "sleep_duration")
                sleepStageName = "Awake"
            case HKCategoryValueSleepAnalysis.inBed.rawValue:
                matchesSleepType = (sleepType == "sleep_duration")
                sleepStageName = "In Bed"
            default:
                return nil
            }
        }

        // Only return data if it matches the requested sleep type
        guard matchesSleepType else {
            return nil
        }

        return [
            "type": sleepType,
            "value": duration,
            "timestamp": timestamp,
            "unit": "minutes",
            "platform": "apple_health",
            "source": sample.sourceRevision.source.name,
            "sleep_stage": sleepStageName
        ]
    }

    /// 通用数据写入方法
    func writeHealthData(
        dataType: String,
        value: Double,
        timestamp: Int64,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard isHealthKitAvailable else {
            completion(false, "HealthKit is not available")
            return
        }

        guard let quantityType = getQuantityType(for: dataType) else {
            completion(false, "Unsupported data type: \(dataType)")
            return
        }

        guard canWriteDataType(dataType) else {
            completion(false, "Data type \(dataType) is not writable")
            return
        }

        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
        let unit = getUnit(for: dataType)
        let quantity = HKQuantity(unit: unit, doubleValue: value)

        let metadata: [String: Any] = [
            HKMetadataKeyWasUserEntered: true,
            "source": HealthManagerConfig.appSource
        ]

        let sample = HKQuantitySample(
            type: quantityType,
            quantity: quantity,
            start: date,
            end: date,
            metadata: metadata
        )

        saveHealthData(sample, completion: completion)
    }

    // MARK: - Helper Methods for Data Types

    private func getQuantityType(for dataTypeKey: String) -> HKQuantityType? {
        let typeMap: [String: HKQuantityTypeIdentifier] = [
            "steps": .stepCount,
            "distance": .distanceWalkingRunning,
            "active_calories": .activeEnergyBurned,
            "glucose": .bloodGlucose,
            "heart_rate": .heartRate,
            "blood_pressure_systolic": .bloodPressureSystolic,
            "blood_pressure_diastolic": .bloodPressureDiastolic,
            "weight": .bodyMass,
            "height": .height,
            "body_fat": .bodyFatPercentage,
            "bmi": .bodyMassIndex,
            "oxygen_saturation": .oxygenSaturation,
            "body_temperature": .bodyTemperature,
            "respiratory_rate": .respiratoryRate,
            "water": .dietaryWater
        ]

        guard let identifier = typeMap[dataTypeKey] else {
            return nil
        }

        return HKQuantityType.quantityType(forIdentifier: identifier)
    }

    private func getUnit(for dataTypeKey: String) -> HKUnit {
        switch dataTypeKey {
        case "steps":
            return HealthUnits.count
        case "distance":
            return .meter()
        case "active_calories":
            return HealthUnits.kilocalorie
        case "glucose":
            return HealthUnits.bloodGlucose
        case "heart_rate":
            return HealthUnits.beatsPerMinute
        case "blood_pressure_systolic", "blood_pressure_diastolic":
            return HealthUnits.mmHg
        case "weight":
            return HealthUnits.kilogram
        case "height":
            return .meter()
        case "body_fat", "bmi", "oxygen_saturation":
            return .percent()
        case "body_temperature":
            return .degreeCelsius()
        case "respiratory_rate":
            return HKUnit.count().unitDivided(by: .minute())
        case "water":
            return .literUnit(with: .milli)
        default:
            return HealthUnits.count
        }
    }

    private func getUnitString(for dataTypeKey: String) -> String {
        switch dataTypeKey {
        case "steps":
            return "count"
        case "distance":
            return "meters"
        case "active_calories":
            return "kcal"
        case "glucose":
            return "mmol/L"
        case "heart_rate":
            return "bpm"
        case "blood_pressure_systolic", "blood_pressure_diastolic":
            return "mmHg"
        case "weight":
            return "kg"
        case "height":
            return "m"
        case "body_fat", "bmi":
            return "%"
        case "oxygen_saturation":
            return "%"
        case "body_temperature":
            return "°C"
        case "respiratory_rate":
            return "breaths/min"
        case "water":
            return "ml"
        default:
            return ""
        }
    }

    private func createDataDictionary(from sample: HKQuantitySample, dataType: String) -> [String: Any] {
        let unit = getUnit(for: dataType)
        let value = sample.quantity.doubleValue(for: unit)
        let timestamp = Int64(sample.startDate.timeIntervalSince1970 * 1000)

        return [
            "type": dataType,
            "value": value,
            "timestamp": timestamp,
            "unit": getUnitString(for: dataType),
            "platform": "apple_health",
            "source": sample.sourceRevision.source.name
        ]
    }

    // MARK: - Cleanup
    func disconnect() {
        // 停止所有活跃查询
        activeQueries.forEach { healthStore.stop($0) }
        activeQueries.removeAll()
    }
}