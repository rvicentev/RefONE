import SwiftUI
import MapKit
import HealthKit
import Charts
import Combine

// MARK: - ESTRUCTURAS DE AYUDA (GRID & HEATMAP)
// (Estas no cambian, pero las incluyo para que puedas copiar el archivo entero sin miedo)

struct GridKey: Hashable {
    let x: Int
    let y: Int
}

struct HeatBin: Identifiable {
    let id = UUID()
    let center: CLLocationCoordinate2D
    let intensity: Double
    
    func polygonCoordinates(gridSizeDegrees: Double) -> [CLLocationCoordinate2D] {
        let halfSize = gridSizeDegrees / 2.0
        return [
            CLLocationCoordinate2D(latitude: center.latitude - halfSize, longitude: center.longitude - halfSize),
            CLLocationCoordinate2D(latitude: center.latitude - halfSize, longitude: center.longitude + halfSize),
            CLLocationCoordinate2D(latitude: center.latitude + halfSize, longitude: center.longitude + halfSize),
            CLLocationCoordinate2D(latitude: center.latitude + halfSize, longitude: center.longitude - halfSize)
        ]
    }
    
    var color: Color {
        if intensity > 0.75 { return Color.red.opacity(0.6) }
        else if intensity > 0.40 { return Color.orange.opacity(0.5) }
        else { return Color.yellow.opacity(0.4) }
    }
}

struct DatoZona: Identifiable {
    let id = UUID()
    let nombre: String
    let minutos: Double
    let color: Color
}

// MARK: - VISTA PRINCIPAL

struct DetallePartidoView: View {
    @Bindable var partido: Partido // <--- CAMBIO IMPORTANTE: @Bindable para que se actualice al editar
    @StateObject private var vm = DetallePartidoViewModel()
    @State private var mostrandoEdicion = false // <--- NUEVO: Controla la ventana de editar
    
    private let heatGridSize = 0.00015
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                
                // 1. FECHA Y HORA
                Text(partido.fecha.formatted(date: .long, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
                
                // 2. ESTADIO
                HStack {
                    Image(systemName: "sportscourt")
                    Text(partido.equipoLocal?.estadio?.nombre ?? "Estadio desconocido")
                }
                .font(.headline)
                .padding(.top, 5)
                
                // 3. MARCADOR
                HStack(alignment: .center, spacing: 30) {
                    VStack {
                        ImagenEscudo(data: partido.equipoLocal?.escudoData, size: 70)
                        Text(partido.equipoLocal?.nombre ?? "Local")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                        // Lógica de color actualizada
                        Rectangle()
                            .fill((!partido.colorLocalHexPartido.isEmpty ? partido.colorLocalHexPartido : partido.equipoLocal?.colorHex ?? "#000000").toColor())
                            .frame(height: 4)
                    }
                    .frame(width: 100)
                    
                    VStack {
                        Text("\(partido.golesLocal) - \(partido.golesVisitante)")
                            .font(.system(size: 40, weight: .heavy))
                            .monospacedDigit()
                        Text("FINAL")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    
                    VStack {
                        ImagenEscudo(data: partido.equipoVisitante?.escudoData, size: 70)
                        Text(partido.equipoVisitante?.nombre ?? "Visitante")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                        // Lógica de color actualizada
                        Rectangle()
                            .fill((!partido.colorVisitanteHexPartido.isEmpty ? partido.colorVisitanteHexPartido : partido.equipoVisitante?.colorVisitanteHex ?? "#FFFFFF").toColor())
                            .frame(height: 4)
                    }
                    .frame(width: 100)
                }
                .padding(.vertical, 20)
                
                // MOSTRAR DINERO (Si hay desplazamiento) - NUEVO VISUAL
                if partido.costeDesplazamiento > 0 {
                    HStack {
                        Image(systemName: "car.fill")
                        Text("Desplazamiento: \(partido.costeDesplazamiento.formatted(.currency(code: "EUR")))")
                    }
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.green)
                    .padding(6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(5)
                    .padding(.bottom, 5)
                }
                
                // 4. ETIQUETA CATEGORÍA
                Text(partido.categoria?.nombre.uppercased() ?? "AMISTOSO")
                    .font(.caption)
                    .bold()
                    .padding(6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(5)
                
                Divider().padding(.vertical, 20)
                
                // 5. MÉTRICAS Y GRÁFICAS (HEALTHKIT)
                if vm.datosDisponibles {
                    VStack(alignment: .leading, spacing: 30) {
                        
                        HStack {
                            Text("Rendimiento Físico")
                                .font(.title2).bold()
                            Spacer()
                            if vm.esSimulado {
                                Label("Simulación", systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .padding(6)
                                    .background(.orange.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.horizontal)
                        
                        // A. GRID DE DATOS
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                            DatoMetricView(titulo: "Duración", valor: vm.duracionString, icono: "stopwatch", color: .blue)
                            DatoMetricView(titulo: "Distancia", valor: String(format: "%.2f km", vm.distancia / 1000), icono: "figure.run", color: .green)
                            DatoMetricView(titulo: "Calorías", valor: String(format: "%.0f kcal", vm.calorias), icono: "flame.fill", color: .orange)
                            DatoMetricView(titulo: "Frecuencia Media", valor:String(format: "%.0f bpm", vm.ppmMedia), icono: "heart.fill", color: .red)
                            DatoMetricView(titulo: "Velocidad Máx", valor: String(format: "%.1f km/h", vm.velocidadMaxima), icono: "speedometer", color: .purple)
                            DatoMetricView(titulo: "Pasos Totales", valor: "\(vm.pasosTotales)", icono: "shoeprints.fill", color: .cyan)
                        }
                        .padding(.horizontal)
                        
                        // B. MAPA DE CALOR + RUTA
                        if !vm.heatMapBins.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Mapa de Calor y Ruta")
                                        .font(.headline)
                                    Image(systemName: "map.fill").foregroundStyle(.blue)
                                }
                                .padding(.horizontal)
                                
                                Map {
                                    ForEach(vm.heatMapBins) { bin in
                                        MapPolygon(coordinates: bin.polygonCoordinates(gridSizeDegrees: heatGridSize))
                                            .foregroundStyle(bin.color)
                                    }
                                    if !vm.rutaCoordenadasPublica.isEmpty {
                                        MapPolyline(coordinates: vm.rutaCoordenadasPublica)
                                            .stroke(.blue, lineWidth: 3)
                                    }
                                }
                                .mapStyle(.imagery(elevation: .realistic))
                                .frame(height: 350)
                                .cornerRadius(12)
                                .padding(.horizontal)
                                
                                Text("El mapa muestra la densidad de movimiento (colores) y la ruta exacta (línea azul).")
                                    .font(.caption2)
                                    .italic()
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                            }
                        } else {
                            ContentUnavailableView("Sin GPS", systemImage: "location.slash", description: Text("Hay datos de salud, pero no se guardó la ruta GPS."))
                        }
                        
                        // C. GRÁFICA DE ZONAS
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Zonas de Esfuerzo")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Chart(vm.zonasCardiacas) { zona in
                                BarMark(
                                    x: .value("Zona", zona.nombre),
                                    y: .value("Minutos", zona.minutos)
                                )
                                .foregroundStyle(zona.color)
                                .cornerRadius(4)
                            }
                            .chartYAxisLabel("Minutos")
                            .frame(height: 200)
                            .padding(.horizontal)
                        }
                    }
                } else if vm.cargando {
                    VStack(spacing: 15) {
                        ProgressView().scaleEffect(1.5)
                        Text("Analizando datos de Salud...")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(height: 200)
                } else {
                    ContentUnavailableView("Sin datos físicos", systemImage: "heart.slash", description: Text("No se encontró registro de HealthKit asociado a este partido."))
                        .padding(.top, 40)
                }
            }
            .padding(.bottom, 50)
        }
        .navigationTitle("Detalle Partido")
        .navigationBarTitleDisplayMode(.inline)
        // --- AQUÍ ESTÁ EL BOTÓN DE EDITAR ---
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar") {
                    mostrandoEdicion = true
                }
            }
        }
        // --- AQUÍ SE ABRE LA PANTALLA DE EDICIÓN ---
        .sheet(isPresented: $mostrandoEdicion) {
            NavigationStack {
                EditarPartidoView(partido: partido)
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            vm.cargarEntrenamiento(id: partido.workoutID)
        }
        .onDisappear {
            if vm.distancia > 0 {
                partido.distanciaRecorrida = vm.distancia
                partido.caloriasQuemadas = vm.calorias
            }
        }
    }
}

// MARK: - NUEVA VISTA: EDITAR PARTIDO
// Esta vista permite modificar los datos de un partido ya creado

struct EditarPartidoView: View {
    @Environment(\.dismiss) var dismiss
    var partido: Partido
    
    // Variables temporales para editar
    @State private var coste: Double = 0.0
    @State private var golesL: Int = 0
    @State private var golesV: Int = 0
    @State private var colorL: Color = .black
    @State private var colorV: Color = .white
    @State private var usarColores: Bool = false
    
    var body: some View {
        Form {
            Section("Económico") {
                HStack {
                    Text("Desplazamiento (€)")
                    TextField("0.0", value: $coste, format: .currency(code: "EUR"))
                        .keyboardType(.decimalPad)
                }
                Text("Modifica este valor para ajustar tus ganancias.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            
            Section("Resultado") {
                Stepper("Goles Local: \(golesL)", value: $golesL)
                Stepper("Goles Visitante: \(golesV)", value: $golesV)
            }
            
            Section("Equipaciones (Visual)") {
                Toggle("Colores Personalizados", isOn: $usarColores)
                if usarColores {
                    ColorPicker("Color Local", selection: $colorL)
                    ColorPicker("Color Visitante", selection: $colorV)
                }
            }
        }
        .navigationTitle("Editar Partido")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    guardarCambios()
                    dismiss()
                }
                .bold()
            }
        }
        .onAppear {
            // Cargar datos actuales del partido al abrir
            coste = partido.costeDesplazamiento
            golesL = partido.golesLocal
            golesV = partido.golesVisitante
            
            if !partido.colorLocalHexPartido.isEmpty {
                usarColores = true
                colorL = partido.colorLocalHexPartido.toColor()
                colorV = partido.colorVisitanteHexPartido.toColor()
            } else {
                // Si no tiene personalizados, cargamos los del equipo por defecto
                colorL = partido.equipoLocal?.colorHex.toColor() ?? .black
                colorV = partido.equipoVisitante?.colorVisitanteHex.toColor() ?? .white
            }
        }
    }
    
    func guardarCambios() {
        // Guardamos los cambios
        partido.costeDesplazamiento = coste
        partido.golesLocal = golesL
        partido.golesVisitante = golesV
        
        // 👇 AÑADE ESTO: Si editamos y guardamos, asumimos que el partido vale
        partido.finalizado = true
        
        if usarColores {
            partido.colorLocalHexPartido = colorL.toHex() ?? "#000000"
            partido.colorVisitanteHexPartido = colorV.toHex() ?? "#FFFFFF"
        } else {
            partido.colorLocalHexPartido = ""
            partido.colorVisitanteHexPartido = ""
        }
    }
}

// MARK: - VIEW MODEL Y RESTO DE COMPONENTES
// (El ViewModel y los componentes visuales de abajo se quedan IGUAL que antes.
//  Simplemente pégalos aquí debajo si no los tienes en este bloque)

class DetallePartidoViewModel: ObservableObject {
    @Published var datosDisponibles = false
    @Published var esSimulado = false
    @Published var cargando = true
    
    // Métricas
    @Published var calorias: Double = 0
    @Published var distancia: Double = 0
    @Published var ppmMedia: Double = 0
    @Published var duracionString: String = "--"
    @Published var velocidadMaxima: Double = 0
    @Published var pasosTotales: Int = 0
    
    // Gráficas y Mapas
    @Published var zonasCardiacas: [DatoZona] = []
    @Published var heatMapBins: [HeatBin] = []
    @Published var rutaCoordenadasPublica: [CLLocationCoordinate2D] = []
    
    // Privados
    private var rutaCoordenadasRaw: [CLLocationCoordinate2D] = []
    private let healthStore = HKHealthStore()
    private let calculationGridSize = 0.00015
    
    func solicitarPermisosLectura() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let tiposALeer: Set<HKObjectType> = [
            HKObjectType.workoutType(), HKSeriesType.workoutRoute(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .runningSpeed)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!
        ]
        healthStore.requestAuthorization(toShare: nil, read: tiposALeer) { _, _ in }
    }
    
    func cargarEntrenamiento(id: UUID?) {
        solicitarPermisosLectura()
        
        guard let id = id else {
            print("⚠️ Partido sin ID de Workout. Cargando simulados.")
            cargarDatosSimulados()
            return
        }
        
        print("🔍 Buscando Workout con ID: \(id.uuidString)")
        let predicate = HKQuery.predicateForObject(with: id)
        let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
            
            guard let workouts = samples as? [HKWorkout], let workout = workouts.first else {
                print("❌ No se encontró el workout. Activando simulación.")
                DispatchQueue.main.async { self.cargarDatosSimulados() }
                return
            }
            
            DispatchQueue.main.async { self.procesarDatosReales(workout: workout) }
        }
        healthStore.execute(query)
    }
    
    func procesarDatosReales(workout: HKWorkout) {
        self.calorias = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
        self.distancia = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        self.duracionString = self.formatearDuracion(workout.duration)
        
        self.cargarFrecuenciaCardiaca(workout: workout)
        self.cargarVelocidadMaxima(workout: workout)
        self.cargarPasos(workout: workout)
        self.cargarRuta(workout: workout)
    }
    
    func cargarVelocidadMaxima(workout: HKWorkout) {
        guard let speedType = HKQuantityType.quantityType(forIdentifier: .runningSpeed) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        let query = HKStatisticsQuery(quantityType: speedType, quantitySamplePredicate: predicate, options: .discreteMax) { _, result, _ in
            if let maxSpeed = result?.maximumQuantity() {
                let mps = maxSpeed.doubleValue(for: HKUnit.meter().unitDivided(by: .second()))
                DispatchQueue.main.async { self.velocidadMaxima = mps * 3.6 }
            }
        }
        healthStore.execute(query)
    }
    
    func cargarPasos(workout: HKWorkout) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            if let sum = result?.sumQuantity() {
                DispatchQueue.main.async { self.pasosTotales = Int(sum.doubleValue(for: .count())) }
            }
        }
        healthStore.execute(query)
    }
    
    func cargarFrecuenciaCardiaca(workout: HKWorkout) {
        let tipoHR = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        let statsQuery = HKStatisticsQuery(quantityType: tipoHR, quantitySamplePredicate: predicate, options: .discreteAverage) { _, stats, _ in
            if let avg = stats?.averageQuantity() {
                DispatchQueue.main.async {
                    self.ppmMedia = avg.doubleValue(for: HKUnit(from: "count/min"))
                    self.generarZonasCardiacas(media: self.ppmMedia, duracionTotal: workout.duration)
                }
            } else {
                DispatchQueue.main.async { self.generarZonasCardiacas(media: 0, duracionTotal: workout.duration) }
            }
        }
        healthStore.execute(statsQuery)
    }
    
    func cargarRuta(workout: HKWorkout) {
        self.rutaCoordenadasRaw = []
        let tipoRuta = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)
        
        let rutaQuery = HKSampleQuery(sampleType: tipoRuta, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            guard let rutas = samples as? [HKWorkoutRoute] else {
                DispatchQueue.main.async { self.finalizarCarga() }
                return
            }
            
            let grupo = DispatchGroup()
            for ruta in rutas {
                grupo.enter()
                let queryDatos = HKWorkoutRouteQuery(route: ruta) { query, locations, done, error in
                    if let locations = locations {
                        self.rutaCoordenadasRaw.append(contentsOf: locations.map { $0.coordinate })
                    }
                    if done { grupo.leave() }
                }
                self.healthStore.execute(queryDatos)
            }
            
            grupo.notify(queue: .main) {
                self.rutaCoordenadasPublica = self.rutaCoordenadasRaw
                self.generarMapaCalor()
                self.finalizarCarga()
            }
        }
        healthStore.execute(rutaQuery)
    }
    
    func finalizarCarga() {
        self.esSimulado = false; self.datosDisponibles = true; self.cargando = false
    }
    
    private func generarMapaCalor() {
        guard !rutaCoordenadasRaw.isEmpty else { return }
        var gridCounts: [GridKey: Int] = [:]
        var maxCount = 0
        for coord in rutaCoordenadasRaw {
            let gridX = Int(coord.latitude / calculationGridSize)
            let gridY = Int(coord.longitude / calculationGridSize)
            let key = GridKey(x: gridX, y: gridY)
            let newCount = (gridCounts[key] ?? 0) + 1
            gridCounts[key] = newCount
            maxCount = max(maxCount, newCount)
        }
        guard maxCount > 0 else { return }
        var bins: [HeatBin] = []
        for (key, count) in gridCounts {
            let centerLat = (Double(key.x) * calculationGridSize) + (calculationGridSize / 2.0)
            let centerLon = (Double(key.y) * calculationGridSize) + (calculationGridSize / 2.0)
            bins.append(HeatBin(center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon), intensity: Double(count) / Double(maxCount)))
        }
        self.heatMapBins = bins
    }
    
    func generarZonasCardiacas(media: Double, duracionTotal: TimeInterval) {
        let minutosTotal = duracionTotal / 60
        self.zonasCardiacas = [
            DatoZona(nombre: "Z1", minutos: minutosTotal * 0.15, color: .blue.opacity(0.6)),
            DatoZona(nombre: "Z2", minutos: minutosTotal * 0.25, color: .green.opacity(0.8)),
            DatoZona(nombre: "Z3", minutos: minutosTotal * 0.40, color: .yellow),
            DatoZona(nombre: "Z4", minutos: minutosTotal * 0.15, color: .orange),
            DatoZona(nombre: "Z5", minutos: minutosTotal * 0.05, color: .red)
        ]
    }
    
    func formatearDuracion(_ duracion: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duracion) ?? ""
    }
    
    func cargarDatosSimulados() {
        self.calorias = 680; self.distancia = 6200; self.ppmMedia = 148
        self.duracionString = "48m 12s"; self.velocidadMaxima = 27.5; self.pasosTotales = 5100
        self.generarZonasCardiacas(media: 148, duracionTotal: 2900)
        let centroLat = 40.4530; let centroLon = -3.6883
        self.rutaCoordenadasRaw = []
        for _ in 0...300 {
            let rLat = Double.random(in: -0.001...0.001); let rLon = Double.random(in: -0.001...0.001)
            self.rutaCoordenadasRaw.append(CLLocationCoordinate2D(latitude: centroLat + rLat, longitude: centroLon + rLon))
        }
        self.rutaCoordenadasPublica = self.rutaCoordenadasRaw
        self.generarMapaCalor()
        self.esSimulado = true; self.datosDisponibles = true; self.cargando = false
    }
}

// MARK: - COMPONENTES VISUALES

struct DatoMetricView: View {
    let titulo: String; let valor: String; let icono: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: icono).foregroundStyle(color); Text(titulo).font(.caption).foregroundStyle(.secondary) }
            Text(valor).font(.headline).bold().monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(12).shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
}

struct ImagenEscudo: View {
    let data: Data?; let size: CGFloat
    var body: some View {
        if let data = data, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle()).overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
        } else {
            Circle().fill(Color.gray.opacity(0.1)).frame(width: size, height: size).overlay(Image(systemName: "shield.fill").font(.system(size: size * 0.5)).foregroundStyle(.gray.opacity(0.5)))
        }
    }
}
