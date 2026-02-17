import SwiftUI
import SwiftData
import WatchConnectivity
import Combine

struct ListaPartidosView: View {
    // Contexto de datos
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Partido.fecha, order: .forward) private var todosLosPartidos: [Partido]
    
    // Estado de la vista
    @State private var filtroSeleccionado = 0
    @State private var esModoCreacion = false
    @State private var mostrandoAlertaSincronizacion = false
    
    // Propiedades computadas para filtrado
    var partidosProximos: [Partido] { todosLosPartidos.filter { !$0.finalizado } }
    var partidosDisputados: [Partido] { todosLosPartidos.filter { $0.finalizado }.reversed() }
    
    var body: some View {
        VStack(spacing: 0) {
            // Segmented Control
            Picker("Estado", selection: $filtroSeleccionado) {
                Text("Próximos").tag(0)
                Text("Finalizados").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            .background(Color(UIColor.systemGroupedBackground))
            
            // Renderizado de listas condicional
            if filtroSeleccionado == 0 {
                ListaGenericaPartidos(partidos: partidosProximos, esDisputado: false)
            } else {
                ListaGenericaPartidos(partidos: partidosDisputados, esDisputado: true)
            }
        }
        .navigationTitle("Partidos")
        .background(Color(UIColor.systemGroupedBackground))
        // 👇 AQUÍ ESTÁN LOS CAMBIOS EN LA TOOLBAR 👇
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    sincronizarReloj()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "applewatch")
                            .symbolEffect(.pulse, isActive: mostrandoAlertaSincronizacion)
                        Text("Sincronizar")
                            .font(.subheadline)
                    }
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    esModoCreacion = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        // 👆 FIN DE LOS CAMBIOS 👆
        
        .sheet(isPresented: $esModoCreacion) {
            NavigationStack { FormularioPartidoView() }
        }
        .alert("Reloj Sincronizado", isPresented: $mostrandoAlertaSincronizacion) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Se han enviado \(partidosProximos.count) partidos al Apple Watch.")
        }
        // Suscripción a actualizaciones remotas (WatchConnectivity)
        .onReceive(NotificationCenter.default.publisher(for: .resultadoPartidoRecibido)) { notification in
            procesarNotificacionResultado(notification)
        }
    }
}

// MARK: - Lógica de Negocio y Sincronización

private extension ListaPartidosView {
    
    func sincronizarReloj() {
        print("[Sync] Iniciando sincronización con Apple Watch...")
        
        let lista = partidosProximos.map { p in
            // Resolución de colores: Override vs Default
            let colorL = !p.colorLocalHexPartido.isEmpty ? p.colorLocalHexPartido : (p.equipoLocal?.colorHex ?? "#000000")
            let colorV = !p.colorVisitanteHexPartido.isEmpty ? p.colorVisitanteHexPartido : (p.equipoVisitante?.colorVisitanteHex ?? "#FFFFFF")
            
            return PartidoReloj(
                id: p.id,
                equipoLocal: p.equipoLocal?.nombre ?? "Local",
                acronimoLocal: p.equipoLocal?.acronimo ?? "LOC",
                colorLocalHex: colorL,
                localEscudoData: comprimirEscudo(p.equipoLocal?.escudoData),
                
                equipoVisitante: p.equipoVisitante?.nombre ?? "Visitante",
                acronimoVisitante: p.equipoVisitante?.acronimo ?? "VIS",
                colorVisitanteHex: colorV,
                visitanteEscudoData: comprimirEscudo(p.equipoVisitante?.escudoData),
                
                estadio: p.equipoLocal?.estadio?.nombre ?? "Campo",
                fecha: p.fecha,
                categoria: p.categoria?.nombre ?? "Amistoso",
                
                duracionParteMinutos: p.categoria?.duracionParteMinutos ?? 45,
                duracionDescansoMinutos: p.categoria?.duracionDescansoMinutos ?? 15,
                
                workoutID: nil
            )
        }
        
        GestorConectividad.shared.enviarPartidosAlReloj(lista)
        mostrandoAlertaSincronizacion = true
    }
    
    func procesarNotificacionResultado(_ notification: Notification) {
        guard let info = notification.userInfo else { return }
        print("[Sync] Payload recibido: \(info)")
        
        // Validación de datos obligatorios
        guard let idString = info["idPartido"] as? String,
              let uuidBuscado = UUID(uuidString: idString),
              let golesL = info["golesLocal"] as? Int,
              let golesV = info["golesVisitante"] as? Int else {
            print("[Sync Error] Datos incompletos en el payload.")
            return
        }
        
        // Búsqueda y actualización
        if let partidoEncontrado = todosLosPartidos.first(where: { $0.id == uuidBuscado }) {
            partidoEncontrado.golesLocal = golesL
            partidoEncontrado.golesVisitante = golesV
            partidoEncontrado.finalizado = true
            
            // Asociación opcional de WorkoutID
            if let wIDString = info["workoutID"] as? String, let wUUID = UUID(uuidString: wIDString) {
                partidoEncontrado.workoutID = wUUID
                print("[Sync] WorkoutID vinculado correctamente.")
            }
            
            do {
                try contexto.save()
                print("[Sync] Contexto persistido.")
            } catch {
                print("[Sync Error] Fallo al guardar contexto: \(error)")
            }
        } else {
            print("[Sync Error] Partido no encontrado con ID: \(uuidBuscado)")
        }
    }
    
    func comprimirEscudo(_ data: Data?) -> Data? {
        guard let data = data, let image = UIImage(data: data) else { return nil }
        let newSize = CGSize(width: 100, height: 100)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage?.jpegData(compressionQuality: 0.5)
    }
}

// MARK: - Componentes de Lista

struct ListaGenericaPartidos: View {
    let partidos: [Partido]
    let esDisputado: Bool
    @Environment(\.modelContext) private var contexto
    
    var body: some View {
        List {
            if partidos.isEmpty {
                ContentUnavailableView(
                    esDisputado ? "Sin partidos jugados" : "No hay partidos próximos",
                    systemImage: esDisputado ? "sportscourt" : "calendar.badge.plus"
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(partidos) { partido in
                    ZStack {
                        // Navegación invisible
                        NavigationLink(destination: destinationView(for: partido)) {
                            EmptyView()
                        }
                        .opacity(0)
                        
                        // Celda visual
                        CeldaPartido(partido: partido, esDisputado: esDisputado)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            contexto.delete(partido)
                        } label: {
                            Label("Borrar", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    @ViewBuilder
    private func destinationView(for partido: Partido) -> some View {
        if esDisputado {
            DetallePartidoView(partido: partido)
        } else {
            VistaPreviaPartido(partido: partido)
        }
    }
}

struct CeldaPartido: View {
    let partido: Partido
    let esDisputado: Bool
    
    var body: some View {
        Group {
            if esDisputado {
                VistaCeldaDisputado(partido: partido)
            } else {
                VistaCeldaProximo(partido: partido)
            }
        }
    }
}

// MARK: - Celdas Específicas

struct VistaCeldaProximo: View {
    let partido: Partido
    
    var body: some View {
        VStack(spacing: 12) {
            // Etiqueta de Categoría
            Text(partido.categoria?.nombre.uppercased() ?? "PARTIDO")
                .font(.caption2)
                .bold()
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange)
                .clipShape(Capsule())
            
            // Bloque de Enfrentamiento
            HStack(alignment: .center, spacing: 6) {
                // Equipo Local
                HStack(spacing: 4) {
                    ImagenEscudo(data: partido.equipoLocal?.escudoData, size: 24)
                    
                    Rectangle()
                        .fill(resolveColor(hex: partido.colorLocalHexPartido, fallback: partido.equipoLocal?.colorHex, defaultHex: "#000000"))
                        .frame(width: 4, height: 20)
                        .overlay(Rectangle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                    
                    Text(partido.equipoLocal?.nombre ?? "Local")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                
                Text("vs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
                
                // Equipo Visitante
                HStack(spacing: 4) {
                    Text(partido.equipoVisitante?.nombre ?? "Visitante")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Rectangle()
                        .fill(resolveColor(hex: partido.colorVisitanteHexPartido, fallback: partido.equipoVisitante?.colorVisitanteHex, defaultHex: "#FFFFFF"))
                        .frame(width: 4, height: 20)
                        .overlay(Rectangle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                    
                    ImagenEscudo(data: partido.equipoVisitante?.escudoData, size: 24)
                }
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Footer: Fecha y Estadio
            VStack(spacing: 4) {
                Text(partido.fecha.formatted(date: .long, time: .shortened))
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.primary)
                
                HStack(spacing: 4) {
                    Image(systemName: "sportscourt")
                    Text(partido.equipoLocal?.estadio?.nombre ?? "Sin estadio")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    // Helper visual para resolución de colores
    private func resolveColor(hex: String, fallback: String?, defaultHex: String) -> Color {
        let finalHex = !hex.isEmpty ? hex : (fallback ?? defaultHex)
        return finalHex.toColor()
    }
}

struct VistaCeldaDisputado: View {
    let partido: Partido
    
    var body: some View {
        HStack(spacing: 12) {
            // Bloque de Fecha
            VStack(alignment: .center) {
                Text(partido.fecha.formatted(.dateTime.day()))
                    .font(.headline)
                    .bold()
                Text(partido.fecha.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption2)
                    .textCase(.uppercase)
                    .foregroundStyle(.red)
            }
            .frame(width: 40)
            
            Divider()
            
            // Detalles del Partido
            VStack(alignment: .leading, spacing: 6) {
                Text(partido.categoria?.nombre.uppercased() ?? "-")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .clipShape(Capsule())
                
                // Local
                HStack {
                    Rectangle()
                        .fill(resolveColor(hex: partido.colorLocalHexPartido, fallback: partido.equipoLocal?.colorHex, defaultHex: "#000000"))
                        .frame(width: 4, height: 14)
                        .overlay(Rectangle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                    
                    Text(partido.equipoLocal?.nombre ?? "Local")
                        .font(.subheadline)
                        .lineLimit(1)
                }
                
                // Visitante
                HStack {
                    Rectangle()
                        .fill(resolveColor(hex: partido.colorVisitanteHexPartido, fallback: partido.equipoVisitante?.colorVisitanteHex, defaultHex: "#FFFFFF"))
                        .frame(width: 4, height: 14)
                        .overlay(Rectangle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                    
                    Text(partido.equipoVisitante?.nombre ?? "Visitante")
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Marcador Final
            HStack(spacing: 10) {
                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(partido.golesLocal)")
                        .font(.subheadline).monospacedDigit().bold()
                    Text("\(partido.golesVisitante)")
                        .font(.subheadline).monospacedDigit().bold()
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.5))
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
    
    private func resolveColor(hex: String, fallback: String?, defaultHex: String) -> Color {
        let finalHex = !hex.isEmpty ? hex : (fallback ?? defaultHex)
        return finalHex.toColor()
    }
}
