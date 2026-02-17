import SwiftUI
import WatchKit
import WatchConnectivity
import Combine

// MARK: - Time Tracking Engine

class CronometroManager: ObservableObject {
    @Published var tiempoMostrado: TimeInterval = 0
    @Published var estaCorriendo = false
    
    private var fechaInicioTramo: Date?
    private var tiempoAcumuladoAnterior: TimeInterval = 0
    private var timer: Timer?
    
    func start() {
        guard !estaCorriendo else { return }
        fechaInicioTramo = Date()
        estaCorriendo = true
        
        // Loop for UI refresh only; precise calculation relies on Date diffs
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.calcularTiempoActual()
        }
    }
    
    func pause() {
        guard estaCorriendo else { return }
        calcularTiempoActual()
        tiempoAcumuladoAnterior = tiempoMostrado
        fechaInicioTramo = nil
        estaCorriendo = false
        timer?.invalidate()
        timer = nil
    }
    
    func reset() {
        pause()
        tiempoAcumuladoAnterior = 0
        tiempoMostrado = 0
    }
    
    private func calcularTiempoActual() {
        guard let inicio = fechaInicioTramo else { return }
        let tiempoDeEsteTramo = Date().timeIntervalSince(inicio)
        self.tiempoMostrado = self.tiempoAcumuladoAnterior + tiempoDeEsteTramo
    }
}

// MARK: - State Definitions

enum EstadoPartido {
    case previa, primeraParte, descanso, segundaParte, finalizado
}

// MARK: - Main Watch View

struct VistaJuegoActivo: View {
    @Environment(\.dismiss) var dismiss
    let partido: PartidoReloj
    
    // Services
    @StateObject private var healthKit = GestorHealthKit.shared
    @StateObject private var cronoJuego = CronometroManager()
    @StateObject private var cronoDescanso = CronometroManager()
    
    // Game State
    @State private var estado: EstadoPartido = .previa
    @State private var workoutIDFinal: UUID? = nil
    
    // Haptics & Events
    @State private var contadorPausa: Int = 0
    @State private var contadorExcesoDescanso: Int = 0
    
    // Scoreboard
    @State private var golesLocal = 0
    @State private var golesVisitante = 0
    
    // UI Feedback
    @State private var colorParpadeo: Color = .white
    @State private var mostrarGolOverlay = false
    @State private var nombreEquipoGol: String = ""
    @State private var colorEquipoGol: Color = .black
    @State private var minutoGol: Int = 0
    
    // Computed Metrics
    var duracionParteSegundos: Double { Double(partido.duracionParteMinutos * 60) }
    var duracionDescansoSegundos: Double { Double(partido.duracionDescansoMinutos * 60) }
    
    var segundosTranscurridos: Int { Int(cronoJuego.tiempoMostrado) }
    var segundosDescanso: Int { Int(cronoDescanso.tiempoMostrado) }
    var cronometroCorriendo: Bool { cronoJuego.estaCorriendo }
    
    var esTiempoAnadido: Bool {
        return cronoJuego.tiempoMostrado >= duracionParteSegundos
    }
    
    var tiempoTotalJuego: Int {
        return Int(duracionParteSegundos) + segundosTranscurridos
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if estado == .finalizado {
                    VistaResumenFinal(
                        partido: partido,
                        golesL: golesLocal,
                        golesV: golesVisitante,
                        workoutID: workoutIDFinal,
                        onCerrar: { dismiss() }
                    )
                } else {
                    // Header
                    Text(partido.categoria.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(.top, 25)
                        .padding(.bottom, 2)
                    
                    // Scoreboard
                    HStack(alignment: .center, spacing: 6) {
                        Rectangle()
                            .fill(partido.colorLocalHex.toColorWatch())
                            .frame(width: 4, height: 22)
                            .overlay(Rectangle().stroke(Color.white.opacity(0.4), lineWidth: 1))
                        
                        Text(partido.acronimoLocal).font(.headline).bold()
                        Text("\(golesLocal) - \(golesVisitante)").font(.title3).monospacedDigit().padding(.horizontal, 2)
                        Text(partido.acronimoVisitante).font(.headline).bold()
                        
                        Rectangle()
                            .fill(partido.colorVisitanteHex.toColorWatch())
                            .frame(width: 4, height: 22)
                            .overlay(Rectangle().stroke(Color.white.opacity(0.4), lineWidth: 1))
                    }
                    .padding(.bottom, 4)
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // Timer Display
                    zonaCronometro
                        .frame(maxHeight: .infinity)
                    
                    // Controls
                    zonaBotonesAccion.padding(.bottom, 5)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .ignoresSafeArea()
        .gesture(DragGesture(minimumDistance: 30, coordinateSpace: .local).onEnded { value in
            guard estado == .primeraParte || estado == .segundaParte else { return }
            if value.translation.width < 0 { anotarGol(esLocal: false) }
            if value.translation.width > 0 { anotarGol(esLocal: true) }
        })
        .overlay {
            if mostrarGolOverlay {
                ZStack {
                    colorEquipoGol.ignoresSafeArea()
                    VStack(spacing: 10) {
                        Text("¡GOL!").font(.system(size: 40, weight: .black)).foregroundStyle(.white).shadow(radius: 2)
                        Text(nombreEquipoGol).font(.title3).bold().foregroundStyle(.white).shadow(radius: 2)
                        Text("Minuto \(minutoGol)").font(.headline).foregroundStyle(.white.opacity(0.9))
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation { mostrarGolOverlay = false }
                    }
                }
            }
        }
        // Event Loop
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in gestionarLogicaEventos() }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in gestionarParpadeo() }
        .onAppear {
            healthKit.solicitarPermisos()
        }
    }
    
    // MARK: - Subviews
    
    var zonaCronometro: some View {
        VStack(spacing: 0) {
            
            if estado == .previa {
                Spacer()
                Text("00:00")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(colorParpadeo)
                    .minimumScaleFactor(0.8)
                Spacer()
                
            } else if estado == .descanso {
                Spacer()
                VStack(spacing: 0) {
                    Text(formatearTiempo(segundosDescanso))
                        .font(.system(size: 50, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Double(segundosDescanso) > duracionDescansoSegundos ? colorParpadeo : .white)
                        .minimumScaleFactor(0.8)
                    
                    Text(Double(segundosDescanso) > duracionDescansoSegundos ? "TIEMPO EXCEDIDO" : "DESCANSO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Double(segundosDescanso) > duracionDescansoSegundos ? .red : .yellow)
                        .padding(.top, -2)
                }
                .padding(.top, 15)
                Spacer()
                
            } else if estado == .primeraParte || estado == .segundaParte {
                
                Spacer()
                
                if !esTiempoAnadido {
                    // Regular Time
                    VStack(spacing: -5) {
                        Text(formatearTiempo(segundosTranscurridos))
                            .font(.system(size: 52, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(cronometroCorriendo ? .white : colorParpadeo)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                        
                        if estado == .segundaParte {
                            Text(formatearTiempo(tiempoTotalJuego))
                                .font(.system(size: 20, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.gray)
                        }
                    }
                    .padding(.top, estado == .primeraParte ? 5 : 0)
                    
                } else {
                    // Added Time (Injury Time)
                    VStack(spacing: -5) {
                        if estado == .primeraParte {
                            Text(formatearTiempo(Int(duracionParteSegundos)))
                                .font(.system(size: 45, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(.red)
                        } else {
                            Text(formatearTiempo(tiempoTotalJuego))
                                .font(.system(size: 45, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(.red)
                        }
                        
                        Text(formatearTiempo(segundosTranscurridos - Int(duracionParteSegundos)))
                            .font(.system(size: 30, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.yellow)
                        
                        Text("TIEMPO AÑADIDO")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.gray)
                            .padding(.top, 2)
                    }
                }
                Spacer()
            }
        }
    }
    
    var zonaBotonesAccion: some View {
        HStack(spacing: 20) {
            switch estado {
            case .previa:
                Button { iniciarPartido() } label: {
                    Text("COMENZAR").bold()
                }
                .tint(.green)
                .frame(height: 40)
                .clipShape(Capsule())
                
            case .primeraParte, .segundaParte:
                Button { pausarReanudar() } label: {
                    Image(systemName: cronometroCorriendo ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                .tint(cronometroCorriendo ? .yellow : .green)
                .frame(width: 45, height: 45)
                .clipShape(Circle())
                
                Button {
                    if estado == .primeraParte { finalizarParte() } else { finalizarPartido() }
                } label: {
                    Image(systemName: "flag.checkered").font(.title3)
                }
                .tint(.red)
                .frame(width: 45, height: 45)
                .clipShape(Circle())
                
            case .descanso:
                Button("FIN DESCANSO") { prepararSegundaParte() }
                    .font(.system(size: 14, weight: .bold))
                    .tint(.blue)
                    .frame(height: 40)
                    .clipShape(Capsule())
                
            case .finalizado:
                EmptyView()
            }
        }
    }
    
    // MARK: - Logic & Event Handling
    
    func gestionarLogicaEventos() {
        if estado == .primeraParte || estado == .segundaParte {
            if cronometroCorriendo {
                // Check if we just crossed the regulation time threshold
                let diferencia = cronoJuego.tiempoMostrado - duracionParteSegundos
                if diferencia >= 0 && diferencia < 1.2 {
                    WKInterfaceDevice.current().play(.stop)
                }
            } else {
                contadorPausa += 1
                if contadorPausa % 10 == 0 { WKInterfaceDevice.current().play(.retry) }
            }
        } else if estado == .descanso {
            if cronoDescanso.tiempoMostrado > duracionDescansoSegundos {
                contadorExcesoDescanso += 1
                if contadorExcesoDescanso % 10 == 0 { WKInterfaceDevice.current().play(.failure) }
            }
        }
    }
    
    func gestionarParpadeo() {
        if estado == .previa {
            colorParpadeo = (colorParpadeo == .white) ? .green : .white
        }
        if (estado == .primeraParte || estado == .segundaParte) && !cronometroCorriendo {
            colorParpadeo = (colorParpadeo == .white) ? .red : .white
        }
        if estado == .descanso && cronoDescanso.tiempoMostrado > duracionDescansoSegundos {
            colorParpadeo = (colorParpadeo == .white) ? .red : .white
        }
    }
    
    func iniciarPartido() {
        estado = .primeraParte
        cronoJuego.start()
        WKInterfaceDevice.current().play(.start)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.healthKit.iniciarEntrenamiento()
        }
    }
    
    func pausarReanudar() {
        if cronoJuego.estaCorriendo {
            cronoJuego.pause()
            healthKit.pausarEntrenamiento()
            WKInterfaceDevice.current().play(.click)
        } else {
            cronoJuego.start()
            healthKit.reanudarEntrenamiento()
            contadorPausa = 0
            WKInterfaceDevice.current().play(.click)
        }
    }
    
    func finalizarParte() {
        cronoJuego.pause()
        healthKit.pausarEntrenamiento()
        
        estado = .descanso
        cronoDescanso.reset()
        cronoDescanso.start()
        
        WKInterfaceDevice.current().play(.stop)
    }
    
    func prepararSegundaParte() {
        cronoDescanso.pause()
        estado = .segundaParte
        cronoJuego.reset()
        WKInterfaceDevice.current().play(.click)
    }
    
    func finalizarPartido() {
        cronoJuego.pause()
        WKInterfaceDevice.current().play(.success)
        
        healthKit.finalizarEntrenamiento { uuid in
            self.workoutIDFinal = uuid
            self.estado = .finalizado
        }
    }
    
    func anotarGol(esLocal: Bool) {
        if esLocal {
            golesLocal += 1
            nombreEquipoGol = partido.equipoLocal
            colorEquipoGol = partido.colorLocalHex.toColorWatch()
        } else {
            golesVisitante += 1
            nombreEquipoGol = partido.equipoVisitante
            colorEquipoGol = partido.colorVisitanteHex.toColorWatch()
        }
        
        let minutoBase = estado == .segundaParte ? partido.duracionParteMinutos : 0
        minutoGol = (Int(cronoJuego.tiempoMostrado) / 60) + minutoBase + 1
        
        withAnimation { mostrarGolOverlay = true }
        WKInterfaceDevice.current().play(.notification)
    }
    
    func formatearTiempo(_ segundos: Int) -> String {
        let min = segundos / 60
        let sec = segundos % 60
        return String(format: "%02d:%02d", min, sec)
    }
}

// MARK: - Auxiliary Components

struct ImagenEscudoWatch: View {
    let data: Data?
    let size: CGFloat
    
    var body: some View {
        if let data = data, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "shield.fill")
                        .font(.system(size: size * 0.5))
                        .foregroundStyle(.gray.opacity(0.5))
                )
        }
    }
}

struct VistaResumenFinal: View {
    let partido: PartidoReloj
    let golesL: Int
    let golesV: Int
    let workoutID: UUID?
    let onCerrar: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Text("FINAL")
                .font(.headline)
                .bold()
                .foregroundStyle(.orange)
                .padding(.top, 10)
            
            HStack(spacing: 20) {
                // Local
                VStack {
                    ImagenEscudoWatch(data: partido.localEscudoData, size: 40)
                    Rectangle()
                        .fill(partido.colorLocalHex.toColorWatch())
                        .frame(width: 30, height: 4)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                }
                
                // Visitor
                VStack {
                    ImagenEscudoWatch(data: partido.visitanteEscudoData, size: 40)
                    Rectangle()
                        .fill(partido.colorVisitanteHex.toColorWatch())
                        .frame(width: 30, height: 4)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                }
            }
            
            Text("\(golesL) - \(golesV)")
                .font(.system(size: 32, weight: .black))
                .monospacedDigit()
            
            HStack {
                Image(systemName: "pin.fill").foregroundStyle(.red)
                Text(partido.estadio)
            }
            .font(.caption2)
            .foregroundStyle(.gray)
            
            Spacer()
            
            Button {
                GestorConectividad.shared.enviarResultadoAlIphone(
                    idPartido: partido.id,
                    golesLocal: golesL,
                    golesVisitante: golesV,
                    workoutID: workoutID
                )
                onCerrar()
            } label: {
                Text("Guardar y Salir").bold()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.bottom, 5)
        }
    }
}
