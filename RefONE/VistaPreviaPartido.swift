import SwiftUI
import Combine

struct VistaPreviaPartido: View {
    let partido: Partido
    
    @State private var tiempoRestante: String = ""
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Necesario para abrir enlaces (Mapas)
    @Environment(\.openURL) var openURL
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                
                // 1. FECHA
                Text(partido.fecha.formatted(date: .long, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
                
                // 2. EQUIPOS
                HStack(alignment: .top, spacing: 20) {
                    // LOCAL
                    VStack {
                        ImagenEscudo(data: partido.equipoLocal?.escudoData, size: 80)
                        Text(partido.equipoLocal?.nombre ?? "Local")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Capsule()
                            .fill(partido.equipoLocal?.colorHex.toColor() ?? .gray)
                            .frame(height: 5)
                            .overlay(Capsule().stroke(Color.primary.opacity(0.2), lineWidth: 1)) // <--- AÑADIR
                            .padding(.top, 5)
                    }
                    .frame(width: 110)
                    
                    // VS
                    VStack(spacing: 5) {
                        Text("VS")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.secondary.opacity(0.3))
                        
                        Text(partido.categoria?.nombre.uppercased() ?? "-")
                            .font(.caption2)
                            .bold()
                            .padding(6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(5)
                    }
                    .padding(.top, 20)
                    
                    // VISITANTE
                    VStack {
                        ImagenEscudo(data: partido.equipoVisitante?.escudoData, size: 80)
                        Text(partido.equipoVisitante?.nombre ?? "Visitante")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Capsule()
                            .fill(partido.equipoVisitante?.colorVisitanteHex.toColor() ?? .gray)
                            .frame(height: 5)
                            .overlay(Capsule().stroke(Color.primary.opacity(0.2), lineWidth: 1)) // <--- AÑADIR
                            .padding(.top, 5)
                    }
                    .frame(width: 110)
                }
                .padding(.vertical, 30)
                
                Divider().padding(.horizontal)
                
                // 3. CUENTA ATRÁS Y DATOS
                VStack(spacing: 25) {
                    
                    // CONTADOR EN VERTICAL
                    VStack(spacing: 5) {
                        Text("INICIO EN")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.secondary)
                        
                        Text(tiempoRestante)
                            .font(.system(size: 44, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.orange)
                            .contentTransition(.numericText())
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                    }
                    
                    // DATOS VERTICALES (Estadio y Tarifa)
                    VStack(spacing: 0) {
                        
                        // --- BOTÓN MAPA ---
                        Button {
                            abrirEnMapas()
                        } label: {
                            HStack {
                                Image(systemName: "sportscourt.fill")
                                    .foregroundStyle(.blue)
                                    .frame(width: 30)
                                Text("Estadio")
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                // Nombre del estadio y botón IR
                                HStack(spacing: 8) {
                                    Text(partido.equipoLocal?.estadio?.nombre ?? "Por definir")
                                        .bold()
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.trailing)
                                    
                                    // Botón visual "IR"
                                    if partido.equipoLocal?.estadio?.nombre != nil {
                                        Image(systemName: "location.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .padding()
                        }
                        .buttonStyle(.plain) // Para que no parpadee toda la celda feo
                        // ------------------
                        
                        Divider().padding(.leading, 50)
                        
                        // Fila Tarifa
                        // CORRECCIÓN: Usamos el Bool 'actuadoComoPrincipal'
                        let tarifa = partido.actuadoComoPrincipal
                        ? (partido.categoria?.tarifaPrincipal ?? 0)
                        : (partido.categoria?.tarifaAsistente ?? 0)
                        HStack {
                            Image(systemName: "eurosign.circle.fill")
                                .foregroundStyle(.green)
                                .frame(width: 30)
                            Text("Tarifa estimada")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(tarifa))€")
                                .bold()
                        }
                        .padding()
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .padding(20)
                
                Spacer()
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Ficha Técnica")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { _ in actualizarCuentaAtras() }
        .onAppear { actualizarCuentaAtras() }
    }
    
    // --- LÓGICA DE MAPAS ---
    func abrirEnMapas() {
        guard let nombreEstadio = partido.equipoLocal?.estadio?.nombre else { return }
        
        // Convertimos "Campo de Fútbol Municipal" a "Campo+de+Futbol..." para URL
        let terminoBusqueda = nombreEstadio.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "http://maps.apple.com/?q=\(terminoBusqueda)"
        
        if let url = URL(string: urlString) {
            openURL(url)
        }
    }
    
    // --- LÓGICA CUENTA ATRÁS ---
    func actualizarCuentaAtras() {
        let diff = partido.fecha.timeIntervalSince(Date())
        if diff <= 0 {
            tiempoRestante = "00:00:00"
        } else {
            let days = Int(diff) / 86400
            let hours = Int(diff) / 3600 % 24
            let minutes = Int(diff) / 60 % 60
            let seconds = Int(diff) % 60
            
            if days > 0 {
                tiempoRestante = String(format: "%dd %02d:%02d:%02d", days, hours, minutes, seconds)
            } else {
                tiempoRestante = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            }
        }
    }
}
