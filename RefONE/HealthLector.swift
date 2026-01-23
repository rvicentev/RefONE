import Foundation
import HealthKit
import CoreLocation
import Combine

class HealthLector: ObservableObject {
    let healthStore = HKHealthStore()
    
    @Published var distancia: Double = 0.0
    @Published var calorias: Double = 0.0
    @Published var tiempo: TimeInterval = 0
    @Published var rutaCoordenadas: [CLLocationCoordinate2D] = []
    @Published var cargando: Bool = false
    
    // Pedir permiso para LEER en el iPhone
    func solicitarPermisosLectura() {
        let tiposALeer: Set = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: tiposALeer) { _, _ in }
    }
    
    func cargarDatosDePartido(partido: Partido) {
        guard let id = partido.workoutID else { return }
        
        self.cargando = true
        
        // 1. Buscar el Workout por ID
        let predicado = HKQuery.predicateForObjects(with: [id])
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicado, limit: 1, sortDescriptors: nil) { [weak self] _, samples, error in
            
            guard let workout = samples?.first as? HKWorkout else {
                DispatchQueue.main.async { self?.cargando = false }
                return
            }
            
            // 2. Extraer datos básicos
            let dist = workout.totalDistance?.doubleValue(for: .meter()) ?? 0.0
            let cal = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0.0
            let duracion = workout.duration
            
            // 3. Actualizar la UI y EL MODELO (Para que las estadísticas funcionen luego)
            DispatchQueue.main.async {
                self?.distancia = dist
                self?.calorias = cal
                self?.tiempo = duracion
                
                // GUARDAR EN EL PARTIDO PERMANENTEMENTE
                // (Hacemos esto para no tener que consultar HealthKit cada vez)
                if partido.distanciaRecorrida != dist {
                    partido.distanciaRecorrida = dist
                    // Nota: Necesitarías guardar el contexto aquí si tienes acceso,
                    // pero SwiftData suele autoguardar al salir de la vista.
                }
            }
            
            // 4. Cargar la Ruta (Mapa)
            self?.cargarRuta(workout: workout)
        }
        
        healthStore.execute(query)
    }
    
    private func cargarRuta(workout: HKWorkout) {
        let routeType = HKSeriesType.workoutRoute()
        let routePredicate = HKQuery.predicateForObjects(from: workout)
        
        let routeQuery = HKSampleQuery(sampleType: routeType, predicate: routePredicate, limit: 1, sortDescriptors: nil) { [weak self] _, samples, _ in
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
