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
    
    // MARK: - Cleanup
    func disconnect() {
        // 停止所有活跃查询
        activeQueries.forEach { healthStore.stop($0) }
        activeQueries.removeAll()
    }
}