import Foundation
import HealthKit
import CoreLocation
import Combine

class GestorHealthKit: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = GestorHealthKit()
    
    let healthStore = HKHealthStore()
    
    // 1. CONSTRUCTOR DE DATOS (Calorías, Distancia, BPM)
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    
    // 2. CONSTRUCTOR DE RUTA (Nuevo: Solo para el mapa)
    var routeBuilder: HKWorkoutRouteBuilder?
    
    let locationManager = CLLocationManager()
    
    // Datos en vivo
    @Published var frecuenciaCardiaca: Double = 0
    @Published var distancia: Double = 0
    @Published var calorias: Double = 0
    
    var healthKitDisponible: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    override init() {
        super.init()
    }
    
    func solicitarPermisos() {
        let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        let speed = HKObjectType.quantityType(forIdentifier: .runningSpeed)!
        let steps = HKObjectType.quantityType(forIdentifier: .stepCount)!
        
        let workout = HKObjectType.workoutType()
        let route = HKSeriesType.workoutRoute()
        
        let tipos: Set = [heartRate, distance, energy, speed, steps, workout, route]
        
        healthStore.requestAuthorization(toShare: tipos, read: tipos) { success, error in
            if success { print("✅ Permisos HK autorizados") }
            else { print("⚠️ Error permisos HK: \(String(describing: error))") }
        }
        
        DispatchQueue.main.async {
            self.locationManager.delegate = self
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            self.locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func iniciarEntrenamiento() {
        guard healthKitDisponible else { return }
        
        // Arrancamos el GPS
        DispatchQueue.main.async {
            self.locationManager.startUpdatingLocation()
        }
        
        let configuracion = HKWorkoutConfiguration()
        configuracion.activityType = .soccer
        configuracion.locationType = .outdoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuracion)
            builder = session?.associatedWorkoutBuilder()
            
            // Inicializamos el constructor de rutas
            routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
            
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuracion)
            builder?.delegate = self
            
            session?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { _, _ in }
            
            print("⚽️ HealthKit arrancado + RouteBuilder listo.")
        } catch {
            print("❌ Error iniciando HK: \(error)")
        }
    }
    
    func pausarEntrenamiento() {
        session?.pause()
    }
    
    func reanudarEntrenamiento() {
        session?.resume()
    }
    
    func finalizarEntrenamiento(completion: @escaping (UUID?) -> Void) {
        // Paramos GPS
        DispatchQueue.main.async {
            self.locationManager.stopUpdatingLocation()
        }
        
        guard let session = session, let builder = builder else {
            completion(nil)
            return
        }
        
        session.end()
        builder.endCollection(withEnd: Date()) { _, _ in
            builder.finishWorkout { workout, error in
                
                guard let workout = workout else {
                    print("❌ Error guardando workout: \(String(describing: error))")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                // AQUÍ ESTÁ LA MAGIA: Guardamos la ruta y la unimos al workout
                self.routeBuilder?.finishRoute(with: workout, metadata: nil) { route, error in
                    if let error = error {
                        print("⚠️ Error guardando ruta: \(error)")
                    } else {
                        print("🗺️ Ruta guardada y vinculada al workout.")
                    }
                    
                    // Devolvemos el UUID al final de todo
                    DispatchQueue.main.async {
                        self.frecuenciaCardiaca = 0
                        self.distancia = 0
                        self.calorias = 0
                        completion(workout.uuid)
                    }
                }
            }
        }
    }
}

// MARK: - DELEGADO DE DATOS (BPM, CALORÍAS)
extension GestorHealthKit: HKLiveWorkoutBuilderDelegate {
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            guard let statistics = workoutBuilder.statistics(for: quantityType) else { continue }
            
            let tipoIdentificador = HKQuantityTypeIdentifier(rawValue: quantityType.identifier)
            
            DispatchQueue.main.async {
                switch tipoIdentificador {
                case .heartRate:
                    let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
                    self.frecuenciaCardiaca = statistics.mostRecentQuantity()?.doubleValue(for: unit) ?? 0
                case .distanceWalkingRunning:
                    let unit = HKUnit.meter()
                    self.distancia = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                case .activeEnergyBurned:
                    let unit = HKUnit.kilocalorie()
                    self.calorias = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                default: break
                }
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) { }
}

// MARK: - DELEGADO GPS (INYECCIÓN MANUAL DE RUTA)
extension GestorHealthKit {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: print("📍✅ GPS: AUTORIZADO")
        default: break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Filtramos coordenadas válidas
        let coordenadasValidas = locations.filter { $0.horizontalAccuracy >= 0 }
        
        guard !coordenadasValidas.isEmpty else { return }
        
        // CORRECCIÓN: Usamos routeBuilder en vez de builder
        routeBuilder?.insertRouteData(coordenadasValidas) { success, error in
            if !success {
                print("⚠️ Error insertando puntos GPS: \(String(describing: error))")
            }
        }
        
        if let ultima = coordenadasValidas.last {
            print("📍 -> HK RouteBuilder: Lat \(ultima.coordinate.latitude)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍❌ Error GPS: \(error.localizedDescription)")
    }
}
