import SwiftUI
import MapKit
import HealthKit
import Charts
import Combine


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

// MARK: - Main View

struct DetallePartidoView: View {
    @Bindable var partido: Partido
    @StateObject private var vm = DetallePartidoViewModel()
    @State private var mostrandoEdicion = false
    
    // Configuración Persistente
    @AppStorage("fcMax") private var fcMax: Double = 190.0
    @AppStorage("limiteZ1") private var limiteZ1: Double = 0.60
    @AppStorage("limiteZ2") private var limiteZ2: Double = 0.70
    @AppStorage("limiteZ3") private var limiteZ3: Double = 0.80
    @AppStorage("limiteZ4") private var limiteZ4: Double = 0.90
    
    private let heatGridSize = 0.00002
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                
                // Header: Date & Time
                Text(partido.fecha.formatted(date: .long, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
                
                // Header: Stadium
                HStack {
                    Image(systemName: "sportscourt")
                    Text(partido.equipoLocal?.estadio?.nombre ?? "Estadio desconocido")
                }
                .font(.headline)
                .padding(.top, 5)
                
                // Scoreboard Section
                HStack(alignment: .center, spacing: 30) {
                    VStack {
                        ImagenEscudo(data: partido.equipoLocal?.escudoData, size: 70)
                        Text(partido.equipoLocal?.nombre ?? "Local")
                            .font(.headline).lineLimit(1)
                        Rectangle().fill((!partido.colorLocalHexPartido.isEmpty ? partido.colorLocalHexPartido : partido.equipoLocal?.colorHex ?? "#000000").toColor()).frame(height: 4)
                    }
                    .frame(width: 100)
                    
                    VStack {
                        Text("\(partido.golesLocal) - \(partido.golesVisitante)")
                            .font(.system(size: 40, weight: .heavy)).monospacedDigit()
                        Text("FINAL").font(.caption).foregroundStyle(.gray)
                    }
                    
                    VStack {
                        ImagenEscudo(data: partido.equipoVisitante?.escudoData, size: 70)
                        Text(partido.equipoVisitante?.nombre ?? "Visitante")
                            .font(.headline).lineLimit(1)
                        Rectangle().fill((!partido.colorVisitanteHexPartido.isEmpty ? partido.colorVisitanteHexPartido : partido.equipoVisitante?.colorVisitanteHex ?? "#FFFFFF").toColor()).frame(height: 4)
                    }
                    .frame(width: 100)
                }
                .padding(.vertical, 20)
                
                // Logistics Cost
                if partido.costeDesplazamiento > 0 {
                    HStack {
                        Image(systemName: "car.fill")
                        Text("Desplazamiento: \(partido.costeDesplazamiento.formatted(.currency(code: "EUR")))")
                    }
                    .font(.caption).bold().foregroundStyle(.green)
                    .padding(6).background(Color.green.opacity(0.1)).cornerRadius(5).padding(.bottom, 5)
                }
                
                Text(partido.categoria?.nombre.uppercased() ?? "AMISTOSO")
                    .font(.caption).bold().padding(6).background(Color.gray.opacity(0.1)).cornerRadius(5)
                
                Divider().padding(.vertical, 20)
                
                // HealthKit Analytics
                if vm.datosDisponibles {
                    VStack(alignment: .leading, spacing: 30) {
                        
                        HStack {
                            Text("Rendimiento Físico").font(.title2).bold()
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // Metrics Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                            DatoMetricView(titulo: "Duración", valor: vm.duracionString, icono: "stopwatch", color: .blue)
                            DatoMetricView(titulo: "Distancia", valor: String(format: "%.2f km", vm.distancia / 1000), icono: "figure.run", color: .green)
                            DatoMetricView(titulo: "Calorías", valor: String(format: "%.0f kcal", vm.calorias), icono: "flame.fill", color: .orange)
                            DatoMetricView(titulo: "Frecuencia Media", valor:String(format: "%.0f bpm", vm.ppmMedia), icono: "heart.fill", color: .red)
                            
                            // 👇 LÓGICA INTELIGENTE: Velocidad o Cadencia
                            if vm.velocidadMaxima > 0.5 {
                                DatoMetricView(titulo: "Velocidad Máx", valor: String(format: "%.1f km/h", vm.velocidadMaxima), icono: "speedometer", color: .purple)
                            } else {
                                // Fallback: Calculamos Cadencia (Pasos / Minuto)
                                let mins = vm.duracionTotal / 60
                                let cadencia = mins > 0 ? Double(vm.pasosTotales) / mins : 0
                                DatoMetricView(titulo: "Cadencia Media", valor: "\(Int(cadencia)) pasos/min", icono: "figure.step.training", color: .purple)
                            }
                            
                            DatoMetricView(titulo: "Pasos Totales", valor: "\(vm.pasosTotales)", icono: "shoeprints.fill", color: .cyan)
                        }
                        .padding(.horizontal)
                        
                        // Heatmap
                        if !vm.heatMapBins.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Mapa de Calor").font(.headline)
                                    Image(systemName: "map.fill").foregroundStyle(.blue)
                                }
                                .padding(.horizontal)
                                
                                Map {
                                    ForEach(vm.heatMapBins) { bin in
                                        MapPolygon(coordinates: bin.polygonCoordinates(gridSizeDegrees: heatGridSize))
                                            .foregroundStyle(bin.color)
                                    }
                                }
                                .mapStyle(.imagery(elevation: .realistic))
                                .frame(height: 350).cornerRadius(12).padding(.horizontal)
                            }
                        }
                        
                        // Heart Rate Zones Chart
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Zonas de Esfuerzo").font(.headline).padding(.horizontal)
                            
                            Chart(vm.zonasCardiacas) { zona in
                                BarMark(x: .value("Zona", zona.nombre), y: .value("Minutos", zona.minutos))
                                    .foregroundStyle(zona.color)
                                    .cornerRadius(4)
                                    .annotation(position: .top) {
                                        Text("\(String(format: "%.0f", zona.minutos))m").font(.caption2).foregroundStyle(.secondary)
                                    }
                            }
                            .chartYAxisLabel("Minutos")
                            .frame(height: 220)
                            .padding(.horizontal)
                            
                            // LEYENDA DINÁMICA
                            VStack(spacing: 8) {
                                Group {
                                    HStack {
                                        Circle().fill(Color.blue.opacity(0.6)).frame(width: 8, height: 8)
                                        Text("Zona 1 (< \(Int(fcMax * limiteZ1)) bpm)")
                                        Spacer()
                                    }
                                    HStack {
                                        Circle().fill(Color.green.opacity(0.8)).frame(width: 8, height: 8)
                                        Text("Zona 2 (\(Int(fcMax * limiteZ1))-\(Int(fcMax * limiteZ2)) bpm)")
                                        Spacer()
                                    }
                                    HStack {
                                        Circle().fill(Color.yellow).frame(width: 8, height: 8)
                                        Text("Zona 3 (\(Int(fcMax * limiteZ2))-\(Int(fcMax * limiteZ3)) bpm)")
                                        Spacer()
                                    }
                                    HStack {
                                        Circle().fill(Color.orange).frame(width: 8, height: 8)
                                        Text("Zona 4 (\(Int(fcMax * limiteZ3))-\(Int(fcMax * limiteZ4)) bpm)")
                                        Spacer()
                                    }
                                    HStack {
                                        Circle().fill(Color.red).frame(width: 8, height: 8)
                                        Text("Zona 5 (> \(Int(fcMax * limiteZ4)) bpm)")
                                        Spacer()
                                    }
                                }
                                .font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)
                        }
                    }
                } else if vm.cargando {
                    VStack(spacing: 15) {
                        ProgressView().scaleEffect(1.5)
                        Text("Analizando datos de Salud...").font(.subheadline).foregroundStyle(.secondary)
                    }.frame(height: 200)
                } else {
                    ContentUnavailableView {
                        Label("Datos no disponibles", systemImage: "heart.slash.circle")
                    } description: {
                        Text(vm.mensajeError ?? "No se encontró información del reloj para este partido.")
                    }
                    .padding(.top, 40)
                }
            }
            .padding(.bottom, 50)
        }
        .navigationTitle("Detalle Partido")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar") { mostrandoEdicion = true }
            }
        }
        .sheet(isPresented: $mostrandoEdicion) {
            NavigationStack { EditarPartidoView(partido: partido) }
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            vm.actualizarConfiguracion(fcMax: fcMax, l1: limiteZ1, l2: limiteZ2, l3: limiteZ3, l4: limiteZ4)
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

// MARK: - Edit View

struct EditarPartidoView: View {
    @Environment(\.dismiss) var dismiss
    var partido: Partido
    @State private var coste: Double = 0.0
    @State private var golesL: Int = 0
    @State private var golesV: Int = 0
    @State private var colorL: Color = .black
    @State private var colorV: Color = .white
    @State private var usarColores: Bool = false
    
    var body: some View {
        Form {
            Section("Económico") {
                HStack { Text("Desplazamiento (€)"); TextField("0.0", value: $coste, format: .currency(code: "EUR")).keyboardType(.decimalPad) }
            }
            Section("Resultado") {
                Stepper("Goles Local: \(golesL)", value: $golesL)
                Stepper("Goles Visitante: \(golesV)", value: $golesV)
            }
            Section("Equipaciones") {
                Toggle("Colores Personalizados", isOn: $usarColores)
                if usarColores {
                    ColorPicker("Color Local", selection: $colorL)
                    ColorPicker("Color Visitante", selection: $colorV)
                }
            }
        }
        .navigationTitle("Editar Partido")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Guardar") { guardarCambios(); dismiss() }.bold() }
        }
        .onAppear {
            coste = partido.costeDesplazamiento
            golesL = partido.golesLocal
            golesV = partido.golesVisitante
            if !partido.colorLocalHexPartido.isEmpty {
                usarColores = true
                colorL = partido.colorLocalHexPartido.toColor()
                colorV = partido.colorVisitanteHexPartido.toColor()
            } else {
                colorL = partido.equipoLocal?.colorHex.toColor() ?? .black
                colorV = partido.equipoVisitante?.colorVisitanteHex.toColor() ?? .white
            }
        }
    }
    func guardarCambios() {
        partido.costeDesplazamiento = coste
        partido.golesLocal = golesL
        partido.golesVisitante = golesV
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

// MARK: - ViewModel (Completo)

class DetallePartidoViewModel: ObservableObject {
    @Published var datosDisponibles = false
    @Published var cargando = true
    @Published var mensajeError: String? = nil
    
    @Published var calorias: Double = 0
    @Published var distancia: Double = 0
    @Published var ppmMedia: Double = 0
    @Published var duracionString: String = "--"
    @Published var duracionTotal: TimeInterval = 0
    @Published var velocidadMaxima: Double = 0
    @Published var pasosTotales: Int = 0
    @Published var zonasCardiacas: [DatoZona] = []
    @Published var heatMapBins: [HeatBin] = []
    @Published var rutaCoordenadasPublica: [CLLocationCoordinate2D] = []
    
    private var rutaCoordenadasRaw: [CLLocationCoordinate2D] = []
    private let healthStore = HKHealthStore()
    private let calculationGridSize = 0.00002
    
    // Configuración Inyectada
    private var fcMax: Double = 190.0
    private var limitZ1: Double = 0.60
    private var limitZ2: Double = 0.70
    private var limitZ3: Double = 0.80
    private var limitZ4: Double = 0.90
    
    func actualizarConfiguracion(fcMax: Double, l1: Double, l2: Double, l3: Double, l4: Double) {
        self.fcMax = fcMax
        self.limitZ1 = l1
        self.limitZ2 = l2
        self.limitZ3 = l3
        self.limitZ4 = l4
    }
    
    func solicitarPermisosLectura() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let tiposALeer: Set<HKObjectType> = [
            HKObjectType.workoutType(), HKSeriesType.workoutRoute(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!, HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!, HKObjectType.quantityType(forIdentifier: .runningSpeed)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!
        ]
        healthStore.requestAuthorization(toShare: nil, read: tiposALeer) { _, _ in }
    }
    
    func cargarEntrenamiento(id: UUID?) {
        self.datosDisponibles = false
        self.cargando = true
        self.mensajeError = nil
        
        solicitarPermisosLectura()
        
        guard let id = id else {
            DispatchQueue.main.async {
                self.mensajeError = "Este partido se creó manualmente en el iPhone sin vincular un entrenamiento del reloj."
                self.cargando = false
            }
            return
        }
        
        let predicate = HKQuery.predicateForObject(with: id)
        let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
            
            guard let workouts = samples as? [HKWorkout], let workout = workouts.first else {
                DispatchQueue.main.async {
                    self.mensajeError = "No se encontró el registro en la App Salud. Puede que haya sido eliminado o no se haya sincronizado."
                    self.cargando = false
                }
                return
            }
            
            DispatchQueue.main.async { self.procesarDatosReales(workout: workout) }
        }
        healthStore.execute(query)
    }
    
    func procesarDatosReales(workout: HKWorkout) {
        self.calorias = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
        self.distancia = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        self.duracionTotal = workout.duration // Guardamos el tiempo real
        self.duracionString = self.formatearDuracion(workout.duration)
        
        self.cargarFrecuenciaCardiaca(workout: workout)
        self.cargarVelocidadMaxima(workout: workout)
        self.cargarPasos(workout: workout)
        self.cargarRuta(workout: workout)
        self.calcularZonasReales(workout: workout)
    }
    
    // --- Métodos de carga ---
    
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
                DispatchQueue.main.async { self.ppmMedia = avg.doubleValue(for: HKUnit(from: "count/min")) }
            }
        }
        healthStore.execute(statsQuery)
    }
    
    func calcularZonasReales(workout: HKWorkout) {
        let tipoHR = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        
        let query = HKSampleQuery(sampleType: tipoHR, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, _ in
            guard let muestras = samples as? [HKQuantitySample], !muestras.isEmpty else { return }
            
            var tZ1: TimeInterval = 0; var tZ2: TimeInterval = 0; var tZ3: TimeInterval = 0; var tZ4: TimeInterval = 0; var tZ5: TimeInterval = 0
            
            for i in 0..<(muestras.count - 1) {
                let actual = muestras[i]
                let duracion = min(muestras[i+1].startDate.timeIntervalSince(actual.startDate), 10.0)
                let bpm = actual.quantity.doubleValue(for: HKUnit(from: "count/min"))
                let p = bpm / self.fcMax
                
                if p < self.limitZ1 { tZ1 += duracion }
                else if p < self.limitZ2 { tZ2 += duracion }
                else if p < self.limitZ3 { tZ3 += duracion }
                else if p < self.limitZ4 { tZ4 += duracion }
                else { tZ5 += duracion }
            }
            
            DispatchQueue.main.async {
                self.zonasCardiacas = [
                    DatoZona(nombre: "Z1", minutos: tZ1/60, color: .blue.opacity(0.6)),
                    DatoZona(nombre: "Z2", minutos: tZ2/60, color: .green.opacity(0.8)),
                    DatoZona(nombre: "Z3", minutos: tZ3/60, color: .yellow),
                    DatoZona(nombre: "Z4", minutos: tZ4/60, color: .orange),
                    DatoZona(nombre: "Z5", minutos: tZ5/60, color: .red)
                ]
            }
        }
        healthStore.execute(query)
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
                let rawData = self.rutaCoordenadasRaw
                let rutaFiltrada = self.filtrarPuntosFueraDelCampo(rawData)
                self.rutaCoordenadasPublica = rutaFiltrada
                self.rutaCoordenadasRaw = rutaFiltrada
                
                self.generarMapaCalor()
                self.finalizarCarga()
            }
        }
        healthStore.execute(rutaQuery)
    }
    
    private func filtrarPuntosFueraDelCampo(_ puntos: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard !puntos.isEmpty else { return [] }
        
        let latPromedio = puntos.map { $0.latitude }.reduce(0, +) / Double(puntos.count)
        let lonPromedio = puntos.map { $0.longitude }.reduce(0, +) / Double(puntos.count)
        let centroDelCampo = CLLocation(latitude: latPromedio, longitude: lonPromedio)
        
        let radioMaximoMetros: CLLocationDistance = 85.0
        
        return puntos.filter { coord in
            let ubicacionPunto = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let distancia = ubicacionPunto.distance(from: centroDelCampo)
            return distancia < radioMaximoMetros
        }
    }
    
    func finalizarCarga() {
        self.datosDisponibles = true
        self.cargando = false
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
        
        let saturacion = max(Double(maxCount) * 0.30, 2.0)
        
        var bins: [HeatBin] = []
        for (key, count) in gridCounts {
            let centerLat = (Double(key.x) * calculationGridSize) + (calculationGridSize / 2.0)
            let centerLon = (Double(key.y) * calculationGridSize) + (calculationGridSize / 2.0)
            
            let rawIntensity = Double(count) / saturacion
            let finalIntensity = min(rawIntensity, 1.0)
            
            bins.append(HeatBin(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                intensity: finalIntensity
            ))
        }
        self.heatMapBins = bins
    }
    
    func formatearDuracion(_ duracion: TimeInterval) -> String {
        let formatter = DateComponentsFormatter(); formatter.allowedUnits = [.hour, .minute, .second]; formatter.unitsStyle = .abbreviated; return formatter.string(from: duracion) ?? ""
    }
}

// MARK: - Components

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
