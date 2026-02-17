import SwiftUI

struct ListaPartidosWatchView: View {
    // Connectivity Manager
    @StateObject private var conectividad = GestorConectividad.shared
    
    // Data Source
    var partidosFiltrados: [PartidoReloj] {
        return conectividad.partidosRecibidos
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if partidosFiltrados.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "iphone.gen3.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.gray)
                        
                        Text("Sin partidos")
                            .font(.headline)
                        
                        Text("Sincroniza desde la App del iPhone")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(partidosFiltrados) { partido in
                        NavigationLink(destination: VistaJuegoActivo(partido: partido)) {
                            CeldaPartidoWatch(partido: partido)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                    }
                }
            }
            .navigationTitle("RefONE")
        }
    }
}

// MARK: - Row Component

struct CeldaPartidoWatch: View {
    let partido: PartidoReloj
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            // Header: Date & Time
            HStack {
                Text(partido.fecha, format: .dateTime.day().month())
                    .foregroundStyle(.orange)
                    .bold()
                Spacer()
                Text(partido.fecha, format: .dateTime.hour().minute())
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
            }
            .font(.caption2)
            
            Divider()
                .overlay(.gray.opacity(0.3))
            
            // Teams Section
            VStack(spacing: 6) {
                
                // Local Team
                HStack {
                    Rectangle()
                        .fill(partido.colorLocalHex.toColorWatch())
                        .frame(width: 4, height: 16)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                    
                    Text(partido.acronimoLocal)
                        .font(.system(size: 16, weight: .bold))
                    
                    Text(partido.equipoLocal)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                }
                
                // Visitor Team
                HStack {
                    Rectangle()
                        .fill(partido.colorVisitanteHex.toColorWatch())
                        .frame(width: 4, height: 16)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                    
                    Text(partido.acronimoVisitante)
                        .font(.system(size: 16, weight: .bold))
                    
                    Text(partido.equipoVisitante)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                }
            }
            
            // Footer: Meta Info
            HStack {
                Image(systemName: "sportscourt")
                Text(partido.estadio)
                Spacer()
                Text(partido.categoria.prefix(3).uppercased())
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(4)
            }
            .font(.system(size: 10))
            .foregroundStyle(.gray)
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}
