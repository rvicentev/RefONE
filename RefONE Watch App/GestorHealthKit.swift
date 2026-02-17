import Foundation
import HealthKit
import CoreLocation
import Combine

class GestorHealthKit: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = GestorHealthKit()
    
    // Services
    let healthStore = HKHealthStore()
    let locationManager = CLLocationManager()
    
    // Workout Session State
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    var routeBuilder: HKWorkoutRouteBuilder?
    
    // Live Metrics
    @Published var frecuenciaCardiaca: Double = 0
    @Published var distancia: Double = 0
    @Published var calorias: Double = 0
    
    var healthKitDisponible: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    override init() {
        super.init()
    }
    
    // MARK: - Authorization
    
    func solicitarPermisos() {
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .runningSpeed)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if success {
                print("HealthKit Authorization: Granted")
            } else {
                print("HealthKit Authorization Error: \(String(describing: error))")
            }
        }
        
        DispatchQueue.main.async {
            self.locationManager.delegate = self
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            self.locationManager.requestWhenInUseAuthorization()
        }
    }
    
    // MARK: - Session Management
    
    func iniciarEntrenamiento() {
        guard healthKitDisponible else { return }
        
        DispatchQueue.main.async {
            self.locationManager.startUpdatingLocation()
        }
        
        let configuracion = HKWorkoutConfiguration()
        configuracion.activityType = .soccer
        configuracion.locationType = .outdoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuracion)
            builder = session?.associatedWorkoutBuilder()
            routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
            
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuracion)
            builder?.delegate = self
            
            session?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { _, _ in }
            
            print("HealthKit Session Started. RouteBuilder initialized.")
            
        } catch {
            print("HealthKit Session Start Error: \(error)")
        }
    }
    
    func pausarEntrenamiento() {
        session?.pause()
    }
    
    func reanudarEntrenamiento() {
        session?.resume()
    }
    
    func finalizarEntrenamiento(completion: @escaping (UUID?) -> Void) {
        DispatchQueue.main.async {
            self.locationManager.stopUpdatingLocation()
        }
        
        guard let session = session, let builder = builder else {
            completion(nil)
            return
        }
        
        session.end()
        builder.endCollection(withEnd: Date()) { [weak self] _, _ in
            builder.finishWorkout { workout, error in
                guard let self = self else { return }
                
                guard let workout = workout else {
                    print("Workout Save Error: \(String(describing: error))")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                // Link Route to Workout
                self.routeBuilder?.finishRoute(with: workout, metadata: nil) { _, error in
                    if let error = error {
                        print("Route Save Error: \(error)")
                    } else {
                        print("Route successfully linked to workout.")
                    }
                    
                    DispatchQueue.main.async {
                        self.resetMetrics()
                        completion(workout.uuid)
                    }
                }
            }
        }
    }
    
    private func resetMetrics() {
        self.frecuenciaCardiaca = 0
        self.distancia = 0
        self.calorias = 0
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension GestorHealthKit: HKLiveWorkoutBuilderDelegate {
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  let statistics = workoutBuilder.statistics(for: quantityType) else { continue }
            
            DispatchQueue.main.async {
                switch quantityType.identifier {
                case HKQuantityTypeIdentifier.heartRate.rawValue:
                    let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
                    self.frecuenciaCardiaca = statistics.mostRecentQuantity()?.doubleValue(for: unit) ?? 0
                    
                case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue:
                    let unit = HKUnit.meter()
                    self.distancia = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    
                case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
                    let unit = HKUnit.kilocalorie()
                    self.calorias = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    
                default: break
                }
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events (pause/resume auto-detection) if needed
    }
}

// MARK: - CLLocationManagerDelegate

extension GestorHealthKit {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            print("GPS Access Granted")
        default: break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordenadasValidas = locations.filter { $0.horizontalAccuracy >= 0 }
        guard !coordenadasValidas.isEmpty else { return }
        
        // Feed valid GPS data to HealthKit Route Builder
        routeBuilder?.insertRouteData(coordenadasValidas) { success, error in
            if !success {
                print("Route Data Insertion Error: \(String(describing: error))")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Manager Error: \(error.localizedDescription)")
    }
}
