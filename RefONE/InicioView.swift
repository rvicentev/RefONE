import SwiftUI
import SwiftData

struct InicioView: View {
    // Nombre guardado en memoria del teléfono
    @AppStorage("nombreUsuario") private var nombreUsuario: String = "Árbitro"
    
    // Obtenemos TODOS los partidos para filtrar aquí
    @Query(sort: \Partido.fecha, order: .forward) private var partidos: [Partido]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    
                    // 1. CABECERA DE BIENVENIDA
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Hola, \(nombreUsuario)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        Text("Bienvenido a RefONE")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // 2. TARJETA RESUMEN (ÚLTIMO MES)
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Resumen Mensual")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "calendar")
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        
                        HStack(spacing: 20) {
                            // Dato 1: Partidos
                            DatoResumenView(valor: "\(partidosMes.count)", etiqueta: "Partidos")
                            
                            Divider().background(.white.opacity(0.5))
                            
                            // Dato 2: Goles (Suma total)
                            DatoResumenView(valor: "\(golesMes)", etiqueta: "Goles")
                            
                            Divider().background(.white.opacity(0.5))
                            
                            // Dato 3: Ganancias
                            DatoResumenView(valor: String(format: "%.0f€", gananciasMes), etiqueta: "Ganado")
                        }
                        .padding(.top, 5)
                    }
                    .padding(20)
                    .background(
                        LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(20)
                    .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    // 3. PRÓXIMOS PARTIDOS
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
            }
            .navigationBarHidden(true) // Ocultamos barra estándar para usar nuestro título grande
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
    
    // --- LÓGICA COMPUTADA ---
    
    // Filtrar partidos del último mes (últimos 30 días)
    var partidosMes: [Partido] {
        let now = Date()
        return partidos.filter { partido in
            // Comprobar si es del mismo mes Y año que hoy
            return Calendar.current.isDate(partido.fecha, equalTo: now, toGranularity: .month) && partido.finalizado
        }
    }
    
    var golesMes: Int {
        var suma = 0
        for partido in partidosMes {
            suma += (partido.golesLocal + partido.golesVisitante)
        }
        return suma
    }
    
    // --- GANANCIAS CORREGIDAS (SUMANDO DESPLAZAMIENTO) ---
    var gananciasMes: Double {
        partidosMes.reduce(0.0) { total, p in
            // 1. Tarifa Base
            let tarifa = p.actuadoComoPrincipal
                ? (p.categoria?.tarifaPrincipal ?? 0)
                : (p.categoria?.tarifaAsistente ?? 0)
            
            // 2. Desplazamiento
            return total + tarifa + p.costeDesplazamiento
        }
    }
    
    var proximosPartidos: [Partido] {
        partidos.filter { !$0.finalizado && $0.fecha >= Date().addingTimeInterval(-3600) } // Filtro básicos futuros
    }
}

// Subvista para los datos de la tarjeta naranja
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

// Celda simplificada para la Home
struct CeldaResumenInicio: View {
    let partido: Partido
    
    var body: some View {
        HStack(spacing: 0) {
            // 1. FRANJA DE COLOR (VISUAL IMPACT)
            VStack(spacing: 0) {
                Color(partido.equipoLocal?.colorHex.toColor() ?? .gray)
                Color(partido.equipoVisitante?.colorVisitanteHex.toColor() ?? .gray)
            }
            .frame(width: 6) // Franja fina a la izquierda
            
            // 2. CONTENIDO
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    // CATEGORÍA Y ESTADIO
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
                    
                    // NOMBRES EQUIPOS (Completos)
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
                
                // FECHA Y HORA (Diseño calendario)
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
        .clipShape(RoundedRectangle(cornerRadius: 12)) // Para recortar la franja de color
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
}
