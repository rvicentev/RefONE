import SwiftUI
import WatchKit
import WatchConnectivity
import Combine

// MARK: - GESTOR DE CRONÓMETRO (LÓGICA MATEMÁTICA)
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
        // El timer aquí solo sirve para refrescar la UI, no para calcular
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

// MARK: - ENUM ESTADOS
enum EstadoPartido {
    case previa, primeraParte, descanso, segundaParte, finalizado
}

// MARK: - VISTA PRINCIPAL
struct VistaJuegoActivo: View {
    @Environment(\.dismiss) var dismiss
    let partido: PartidoReloj
    
    // HEALTHKIT
    @StateObject private var healthKit = GestorHealthKit.shared
    
    // NUEVOS GESTORES DE TIEMPO (Sustituyen a los contadores manuales)
    @StateObject private var cronoJuego = CronometroManager()
    @StateObject private var cronoDescanso = CronometroManager()
    
    // ESTADOS
    @State private var estado: EstadoPartido = .previa
    @State private var workoutIDFinal: UUID? = nil
    
    // VIBRACIÓN
    @State private var contadorPausa: Int = 0
    @State private var contadorExcesoDescanso: Int = 0
    
    // MARCADOR
    @State private var golesLocal = 0
    @State private var golesVisitante = 0
    
    // UI FEEDBACK
    @State private var colorParpadeo: Color = .white
    @State private var mostrarGolOverlay = false
    @State private var nombreEquipoGol: String = ""
    @State private var colorEquipoGol: Color = .black
    @State private var minutoGol: Int = 0
    
    // CÁLCULOS
    var duracionParteSegundos: Double { Double(partido.duracionParteMinutos * 60) }
    var duracionDescansoSegundos: Double { Double(partido.duracionDescansoMinutos * 60) }
    
    // Helpers para adaptar tu código anterior a los nuevos gestores
    var segundosTranscurridos: Int { Int(cronoJuego.tiempoMostrado) }
    var segundosDescanso: Int { Int(cronoDescanso.tiempoMostrado) }
    var cronometroCorriendo: Bool { cronoJuego.estaCorriendo }
    
    var esTiempoAnadido: Bool {
        return cronoJuego.tiempoMostrado >= duracionParteSegundos
    }
    
    // Tiempo total (Para la lógica de la 2a parte)
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
                    // 1. CABECERA
                    Text(partido.categoria.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(.top, 25)
                        .padding(.bottom, 2)
                    
                    // 2. MARCADOR
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
                    
                    // 3. ZONA CRONÓMETRO
                    zonaCronometro
                        .frame(maxHeight: .infinity)
                    
                    // 4. BOTONES
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { withAnimation { mostrarGolOverlay = false } }
                }
            }
        }
        // TIMERS DE UI: Solo para chequear eventos (vibración, final de parte), NO para sumar tiempo
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in gestionarLogicaEventos() }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in gestionarParpadeo() }
        .onAppear {
            healthKit.solicitarPermisos()
        }
    }
    
    // --- ZONA CRONÓMETRO ---
    
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
                    // --- TIEMPO REGULAR ---
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
                    // --- TIEMPO AÑADIDO (Descuento) ---
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
                Button { iniciarPartido() } label: { Text("COMENZAR").bold() }.tint(.green).frame(height: 40).clipShape(Capsule())
                
            case .primeraParte, .segundaParte:
                Button { pausarReanudar() } label: { Image(systemName: cronometroCorriendo ? "pause.fill" : "play.fill").font(.title3) }
                    .tint(cronometroCorriendo ? .yellow : .green).frame(width: 45, height: 45).clipShape(Circle())
                
                Button { if estado == .primeraParte { finalizarParte() } else { finalizarPartido() } } label: { Image(systemName: "flag.checkered").font(.title3) }
                    .tint(.red).frame(width: 45, height: 45).clipShape(Circle())
                
            case .descanso:
                Button("FIN DESCANSO") { prepararSegundaParte() }
                    .font(.system(size: 14, weight: .bold)).tint(.blue).frame(height: 40).clipShape(Capsule())
                
            case .finalizado: EmptyView()
            }
        }
    }
    
    // --- LÓGICA MODIFICADA ---
    
    // Esta función ya no suma +1 a una variable. Solo comprueba hitos (fin de parte, vibraciones).
    func gestionarLogicaEventos() {
        if estado == .primeraParte || estado == .segundaParte {
            if cronometroCorriendo {
                // Comprobamos si acabamos de cruzar el umbral del tiempo reglamentario
                // Usamos un rango pequeño (0.0 a 1.2) para asegurar que vibra una vez al llegar al minuto exacto
                let diferencia = cronoJuego.tiempoMostrado - duracionParteSegundos
                if diferencia >= 0 && diferencia < 1.2 {
                    WKInterfaceDevice.current().play(.stop)
                }
            } else {
                contadorPausa += 1
                if contadorPausa % 10 == 0 { WKInterfaceDevice.current().play(.retry) }
            }
        } else if estado == .descanso {
            // El cronoDescanso se encarga de sumar, aquí solo comprobamos si vibramos
            if cronoDescanso.tiempoMostrado > duracionDescansoSegundos {
                contadorExcesoDescanso += 1
                if contadorExcesoDescanso % 10 == 0 { WKInterfaceDevice.current().play(.failure) }
            }
        }
    }
    
    func gestionarParpadeo() {
        if estado == .previa { colorParpadeo = (colorParpadeo == .white) ? .green : .white }
        if (estado == .primeraParte || estado == .segundaParte) && !cronometroCorriendo {
            colorParpadeo = (colorParpadeo == .white) ? .red : .white
        }
        if estado == .descanso && cronoDescanso.tiempoMostrado > duracionDescansoSegundos {
            colorParpadeo = (colorParpadeo == .white) ? .red : .white
        }
    }
    
    // FUNCIONES DE ESTADO
    func iniciarPartido() {
        estado = .primeraParte
        cronoJuego.start() // <--- USAMOS EL GESTOR
        WKInterfaceDevice.current().play(.start)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.healthKit.iniciarEntrenamiento()
        }
    }
    
    func pausarReanudar() {
        if cronoJuego.estaCorriendo {
            cronoJuego.pause() // <--- USAMOS EL GESTOR
            healthKit.pausarEntrenamiento()
            WKInterfaceDevice.current().play(.click)
        } else {
            cronoJuego.start() // <--- USAMOS EL GESTOR
            healthKit.reanudarEntrenamiento()
            contadorPausa = 0
            WKInterfaceDevice.current().play(.click)
        }
    }
    
    func finalizarParte() {
        cronoJuego.pause() // Pausamos el juego
        healthKit.pausarEntrenamiento()
        
        estado = .descanso
        cronoDescanso.reset() // Preparamos el crono del descanso
        cronoDescanso.start() // Arrancamos el crono del descanso
        
        WKInterfaceDevice.current().play(.stop)
    }
    
    func prepararSegundaParte() {
        cronoDescanso.pause() // Paramos el descanso
        
        estado = .segundaParte
        cronoJuego.reset() // Reiniciamos el crono visual para que empiece de 00:00 en la 2a parte
        // No arrancamos (start) hasta que el usuario pulse Play, tal como tenías antes
        
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
        if esLocal { golesLocal += 1; nombreEquipoGol = partido.equipoLocal; colorEquipoGol = partido.colorLocalHex.toColorWatch() }
        else { golesVisitante += 1; nombreEquipoGol = partido.equipoVisitante; colorEquipoGol = partido.colorVisitanteHex.toColorWatch() }
        
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

// STRUCT AUXILIARES (SE MANTIENEN IGUAL)

struct ImagenEscudoWatch: View {
    let data: Data?
    let size: CGFloat
    var body: some View {
        if let data = data, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle())
        } else {
            Circle().fill(Color.gray.opacity(0.3)).frame(width: size, height: size).overlay(Image(systemName: "shield.fill").font(.system(size: size * 0.5)).foregroundStyle(.gray.opacity(0.5)))
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
                // LOCAL
                VStack {
                    ImagenEscudoWatch(data: partido.localEscudoData, size: 40)
                    Rectangle()
                        .fill(partido.colorLocalHex.toColorWatch())
                        .frame(width: 30, height: 4)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                }
                
                // VISITANTE
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
