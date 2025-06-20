import Foundation
import HealthKit
import CoreLocation

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    
    @Published var workouts: [HKWorkout] = []
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        
        let readTypes: Set = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]
        
        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            if let error = error {
                print("❌ Authorization failed: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    func fetchWorkouts() {
        let type = HKObjectType.workoutType()
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 30, sortDescriptors: [sort]) { [weak self] _, samples, error in
            if let error = error {
                print("❌ Failed to fetch workouts: \(error.localizedDescription)")
                return
            }
            guard let workouts = samples as? [HKWorkout] else { return }
            DispatchQueue.main.async {
                self?.workouts = workouts
            }
        }
        healthStore.execute(query)
    }
    
    func fetchRoute(for workout: HKWorkout, completion: @escaping ([CLLocation]) -> Void) {
        let predicate = HKQuery.predicateForObjects(from: workout)
        let routeQuery = HKSampleQuery(sampleType: HKSeriesType.workoutRoute(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, error in
            guard let route = samples?.first as? HKWorkoutRoute else {
                completion([])
                return
            }
            self?.loadRouteLocations(from: route, completion: completion)
        }
        healthStore.execute(routeQuery)
    }
    
    private func loadRouteLocations(from route: HKWorkoutRoute, completion: @escaping ([CLLocation]) -> Void) {
        var allLocations: [CLLocation] = []
        let routeQuery = HKWorkoutRouteQuery(route: route) { _, locationsOrNil, done, error in
            if let locations = locationsOrNil {
                allLocations.append(contentsOf: locations)
            }
            if done {
                DispatchQueue.main.async {
                    completion(allLocations)
                }
            }
        }
        healthStore.execute(routeQuery)
    }
    /// Fetch running and walking workouts from HealthKit.
    func fetchRunningWorkouts(limit: Int = 100,
                              completion: @escaping ([HKWorkout]) -> Void) {
        let workoutType = HKObjectType.workoutType()
        
        // Predicates for running and walking
        let running = HKQuery.predicateForWorkouts(with: .running)
        let walking = HKQuery.predicateForWorkouts(with: .walking)
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [running, walking])
        
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: workoutType,
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sort]) { _, samples, error in
            if let error = error {
                print("❌ Failed to fetch running/walking workouts: \(error.localizedDescription)")
                DispatchQueue.main.async { completion([]) }
                return
            }
            let workouts = samples as? [HKWorkout] ?? []
            DispatchQueue.main.async { completion(workouts) }
        }
        
        healthStore.execute(query)
    }
}
