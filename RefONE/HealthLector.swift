import Foundation
import HealthKit
import CoreLocation
import Combine

class HealthLector: ObservableObject {
    // Services
    let healthStore = HKHealthStore()
    
    // Published State
    @Published var distancia: Double = 0.0
    @Published var calorias: Double = 0.0
    @Published var tiempo: TimeInterval = 0
    @Published var rutaCoordenadas: [CLLocationCoordinate2D] = []
    @Published var cargando: Bool = false
    
    // MARK: - Authorization
    
    func solicitarPermisosLectura() {
        let tiposALeer: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: tiposALeer) { _, _ in }
    }
    
    // MARK: - Data Fetching
    
    func cargarDatosDePartido(partido: Partido) {
        guard let id = partido.workoutID else { return }
        
        self.cargando = true
        
        // Query specific workout by UUID
        let predicado = HKQuery.predicateForObjects(with: [id])
        let query = HKSampleQuery(
            sampleType: .workoutType(),
            predicate: predicado,
            limit: 1,
            sortDescriptors: nil
        ) { [weak self] _, samples, error in
            
            guard let workout = samples?.first as? HKWorkout else {
                DispatchQueue.main.async { self?.cargando = false }
                return
            }
            
            // Extract metrics
            let dist = workout.totalDistance?.doubleValue(for: .meter()) ?? 0.0
            let cal = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0.0
            let duracion = workout.duration
            
            // State and Model update (Main Thread)
            DispatchQueue.main.async {
                self?.distancia = dist
                self?.calorias = cal
                self?.tiempo = duracion
                
                // Persist metrics to Partido model if changed
                if partido.distanciaRecorrida != dist {
                    partido.distanciaRecorrida = dist
                }
            }
            
            // Trigger route retrieval
            self?.cargarRuta(workout: workout)
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Route Geometry
    
    private func cargarRuta(workout: HKWorkout) {
        let routeType = HKSeriesType.workoutRoute()
        let routePredicate = HKQuery.predicateForObjects(from: workout)
        
        let routeQuery = HKSampleQuery(
            sampleType: routeType,
            predicate: routePredicate,
            limit: 1,
            sortDescriptors: nil
        ) { [weak self] _, samples, _ in
            guard let route = samples?.first as? HKWorkoutRoute else { return }
            
            let query = HKWorkoutRouteQuery(route: route) { query, locations, done, error in
                guard let locations = locations else { return }
                
                let coords = locations.map { $0.coordinate }
                
                DispatchQueue.main.async {
                    self?.rutaCoordenadas.append(contentsOf: coords)
                    if done { self?.cargando = false }
                }
            }
            self?.healthStore.execute(query)
        }
        healthStore.execute(routeQuery)
    }
}
