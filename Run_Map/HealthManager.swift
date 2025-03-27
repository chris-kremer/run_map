import CoreLocation
import HealthKit

class HealthManager: ObservableObject {
    private var healthStore = HKHealthStore()
    
    func fetchRunningWorkouts(completion: @escaping ([HKWorkout]) -> Void) {
        let workoutType = HKObjectType.workoutType()
        
        // Create predicates for running and walking workouts
        let runningPredicate = HKQuery.predicateForWorkouts(with: .running)
        let walkingPredicate = HKQuery.predicateForWorkouts(with: .walking)
        // Combine them with OR so that workouts matching either type are returned
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [runningPredicate, walkingPredicate])
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: workoutType,
                                  predicate: predicate,
                                  limit: 0,
                                  sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let workouts = samples as? [HKWorkout], error == nil else {
                print("Error fetching workouts: \(String(describing: error))")
                completion([])
                return
            }
            completion(workouts)
            print("✅ Retrieved \(workouts.count) running/walking workouts")
        }

        healthStore.execute(query)
    }
    
    func fetchRoute(for workout: HKWorkout, completion: @escaping ([CLLocation]) -> Void) {
        let predicate = HKQuery.predicateForObjects(from: workout)
        let routeType = HKSeriesType.workoutRoute()
        
        let routeQuery = HKSampleQuery(sampleType: routeType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
            guard let routes = samples as? [HKWorkoutRoute], let route = routes.first else {
                print("⚠️ No route found for workout on \(workout.startDate)")
                completion([])
                return
            }

            var allLocations: [CLLocation] = []
            
            let routeDataQuery = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                guard let locations = locations else {
                    completion([])
                    return
                }
                allLocations.append(contentsOf: locations)
                
                if done {
                    completion(allLocations)
                    print("✅ Retrieved \(allLocations.count) locations for workout: \(workout.startDate)")
                }
            }
            self.healthStore.execute(routeDataQuery)
        }

        healthStore.execute(routeQuery)
    }
    
    func requestAuthorization() {
        let readTypes: Set = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]

        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            if success {
                print("✅ HealthKit authorization granted")
            } else {
                print("❌ HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
}
