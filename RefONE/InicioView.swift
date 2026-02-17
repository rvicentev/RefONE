import SwiftUI
import SwiftData

struct InicioView: View {
    // Persistent Storage
    @AppStorage("nombreUsuario") private var nombreUsuario: String = "Árbitro"
    
    // Data Query
    @Query(sort: \Partido.fecha, order: .forward) private var partidos: [Partido]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    
                    // MARK: - Cabecera (Header) con Logo a la derecha
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Hola, \(nombreUsuario)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            Text("Bienvenido a RefONE")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image("LogoApp")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 110)
                    }
                    .padding(.top, 20)
                    
                    // MARK: - Monthly Summary Card
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Este mes")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "calendar")
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        
                        HStack(spacing: 20) {
                            DatoResumenView(valor: "\(partidosMes.count)", etiqueta: "Partidos")
                            
                            Divider()
                                .background(.white.opacity(0.5))
                            
                            DatoResumenView(valor: "\(golesMes)", etiqueta: "Goles")
                            
                            Divider()
                                .background(.white.opacity(0.5))
                            
                            DatoResumenView(valor: String(format: "%.0f€", gananciasMes), etiqueta: "Ganado")
                        }
                        .padding(.top, 5)
                    }
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    // MARK: - Upcoming Matches
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Próximos Partidos")
                            .font(.title2)
                            .bold()
                        
                        if proximosPartidos.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 10) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.largeTitle)
                                        .foregroundStyle(.gray)
                                    Text("No tienes partidos programados")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 30)
                                Spacer()
                            }
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        } else {
                            ForEach(proximosPartidos.prefix(3)) { partido in
                                NavigationLink(destination: VistaPreviaPartido(partido: partido)) {
                                    CeldaResumenInicio(partido: partido)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .navigationBarHidden(true)
            .background(
                // MARK: - Fondo con Grid Pattern Minimalista
                ZStack {
                    // Color base
                    Color(UIColor.systemGroupedBackground)
                    
                    // Patrón de grid sutil
                    GeometryReader { geometry in
                        // Líneas verticales
                        ForEach(0..<8) { i in
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.orange.opacity(0.02),
                                            Color.orange.opacity(0.05),
                                            Color.orange.opacity(0.02)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 1)
                                .offset(x: CGFloat(i) * (geometry.size.width / 7))
                        }
                        
                        // Líneas horizontales
                        ForEach(0..<12) { i in
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.orange.opacity(0.02),
                                            Color.orange.opacity(0.05),
                                            Color.orange.opacity(0.02)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 1)
                                .offset(y: CGFloat(i) * (geometry.size.height / 11))
                        }
                    }
                    
                    // Gradiente diagonal superior
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.08),
                            Color.clear
                        ],
                        startPoint: .topTrailing,
                        endPoint: .center
                    )
                    
                    // Gradiente diagonal inferior
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.red.opacity(0.06)
                        ],
                        startPoint: .center,
                        endPoint: .bottomLeading
                    )
                    
                    // Puntos decorativos en esquinas
                    VStack {
                        HStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 4, height: 4)
                                .padding(.top, 100)
                                .padding(.leading, 30)
                            Spacer()
                            Circle()
                                .fill(Color.orange.opacity(0.12))
                                .frame(width: 3, height: 3)
                                .padding(.top, 150)
                                .padding(.trailing, 50)
                        }
                        Spacer()
                        HStack {
                            Circle()
                                .fill(Color.red.opacity(0.10))
                                .frame(width: 3, height: 3)
                                .padding(.bottom, 200)
                                .padding(.leading, 80)
                            Spacer()
                            Circle()
                                .fill(Color.orange.opacity(0.14))
                                .frame(width: 4, height: 4)
                                .padding(.bottom, 150)
                                .padding(.trailing, 40)
                        }
                    }
                }
                .ignoresSafeArea()
            )
        }
    }
}

// MARK: - Computed Logic y Subviews

extension InicioView {
    var partidosMes: [Partido] {
        let now = Date()
        return partidos.filter { partido in
            Calendar.current.isDate(partido.fecha, equalTo: now, toGranularity: .month) && partido.finalizado
        }
    }
    
    var golesMes: Int {
        partidosMes.reduce(0) { $0 + ($1.golesLocal + $1.golesVisitante) }
    }
    
    var gananciasMes: Double {
        partidosMes.reduce(0.0) { total, p in
            let tarifa = p.actuadoComoPrincipal
                ? (p.categoria?.tarifaPrincipal ?? 0)
                : (p.categoria?.tarifaAsistente ?? 0)
            return total + tarifa + p.costeDesplazamiento
        }
    }
    
    var proximosPartidos: [Partido] {
        partidos.filter { !$0.finalizado && $0.fecha >= Date().addingTimeInterval(-3600) }
    }
}

struct DatoResumenView: View {
    let valor: String
    let etiqueta: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(valor)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(etiqueta)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CeldaResumenInicio: View {
    let partido: Partido
    
    var body: some View {
        HStack(spacing: 0) {
            // Visual Indicator Strip
            VStack(spacing: 0) {
                Color(partido.equipoLocal?.colorHex.toColor() ?? .gray)
                Color(partido.equipoVisitante?.colorVisitanteHex.toColor() ?? .gray)
            }
            .frame(width: 6)
            
            // Content
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    // Meta: Category & Stadium
                    HStack {
                        Text(partido.categoria?.nombre.uppercased() ?? "AMISTOSO")
                            .font(.caption2)
                            .bold()
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                        
                        HStack(spacing: 2) {
                            Image(systemName: "sportscourt")
                            Text(partido.equipoLocal?.estadio?.nombre ?? "Campo")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    
                    // Teams
                    VStack(alignment: .leading, spacing: 2) {
                        Text(partido.equipoLocal?.nombre ?? "Local")
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text("vs")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 2)
                        
                        Text(partido.equipoVisitante?.nombre ?? "Visitante")
                            .font(.headline)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Date & Time Block
                VStack(alignment: .center, spacing: 2) {
                    Text(partido.fecha.formatted(.dateTime.day()))
                        .font(.title2)
                        .bold()
                    Text(partido.fecha.formatted(.dateTime.month(.abbreviated)))
                        .font(.caption)
                        .textCase(.uppercase)
                        .foregroundStyle(.red)
                    
                    Text(partido.fecha.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .padding(.top, 4)
                        .foregroundStyle(.gray)
                }
                .padding(.leading, 10)
                .frame(minWidth: 50)
            }
            .padding()
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
}
