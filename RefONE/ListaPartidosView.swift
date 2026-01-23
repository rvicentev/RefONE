import SwiftUI
import SwiftData
import WatchConnectivity
import Combine

struct ListaPartidosView: View {
    @Environment(\.modelContext) private var contexto
    // Traemos todos para buscar por ID cuando llegue el resultado
    @Query(sort: \Partido.fecha, order: .forward) private var todosLosPartidos: [Partido]
    
    @State private var filtroSeleccionado = 0
    @State private var esModoCreacion = false
    @State private var mostrandoAlertaSincronizacion = false
    
    // Filtros
    var partidosProximos: [Partido] { todosLosPartidos.filter { !$0.finalizado } }
    var partidosDisputados: [Partido] { todosLosPartidos.filter { $0.finalizado }.reversed() }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Selector
            Picker("Estado", selection: $filtroSeleccionado) {
                Text("Próximos").tag(0)
                Text("Disputados").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            .background(Color(UIColor.systemGroupedBackground))
            
            // Listas
            if filtroSeleccionado == 0 {
                ListaGenericaPartidos(partidos: partidosProximos, esDisputado: false)
            } else {
                ListaGenericaPartidos(partidos: partidosDisputados, esDisputado: true)
            }
        }
        .navigationTitle("Partidos")
        .background(Color(UIColor.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { sincronizarReloj() } label: {
                    Image(systemName: "applewatch").symbolEffect(.pulse, isActive: mostrandoAlertaSincronizacion)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Crear", systemImage: "plus") { esModoCreacion = true }
            }
        }
        .sheet(isPresented: $esModoCreacion) {
            NavigationStack { FormularioPartidoView() }
        }
        .alert("Reloj Sincronizado", isPresented: $mostrandoAlertaSincronizacion) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Se han enviado \(partidosProximos.count) partidos al Apple Watch.")
        }
        
        // --- AQUÍ RECIBIMOS LOS DATOS DEL RELOJ (Offline y Online) ---

        .onReceive(NotificationCenter.default.publisher(for: .resultadoPartidoRecibido)) { notification in
            print("🔔 NOTIFICACIÓN RECIBIDA EN LISTA PARTIDOS") // <--- CHIVATO 1
            
            guard let info = notification.userInfo else {
                print("❌ La notificación llegó vacía")
                return
            }
            
            // Imprimimos todo lo que llega
            print("📦 Datos crudos: \(info)") // <--- CHIVATO 2
            
            guard let idString = info["idPartido"] as? String,
                  let uuidBuscado = UUID(uuidString: idString),
                  let golesL = info["golesLocal"] as? Int,
                  let golesV = info["golesVisitante"] as? Int else {
                print("❌ Faltan datos básicos en el paquete")
                return
            }

            print("🔎 Buscando partido con ID: \(uuidBuscado)")

            if let partidoEncontrado = todosLosPartidos.first(where: { $0.id == uuidBuscado }) {
                print("✅ Partido encontrado en base de datos. Actualizando...")
                
                partidoEncontrado.golesLocal = golesL
                partidoEncontrado.golesVisitante = golesV
                partidoEncontrado.finalizado = true
                
                // REVISIÓN DEL WORKOUT ID
                if let wIDString = info["workoutID"] as? String {
                    print("🏋️‍♂️ El Reloj ha mandado un WorkoutID: \(wIDString)")
                    if let wUUID = UUID(uuidString: wIDString) {
                        partidoEncontrado.workoutID = wUUID
                        print("💾 ¡GUARDADO! ID vinculado al partido.")
                    } else {
                        print("❌ El ID de workout no tiene formato UUID válido.")
                    }
                } else {
                    print("⚠️ EL RELOJ NO HA MANDADO 'workoutID'. El campo está vacío.")
                }
                
                do {
                    try contexto.save()
                    print("💾 Contexto de SwiftData guardado.")
                } catch {
                    print("❌ Error guardando contexto: \(error)")
                }
                
            } else {
                print("❌ ERROR CRÍTICO: No encuentro el partido en el iPhone. IDs disponibles: \(todosLosPartidos.map { $0.id })")
            }
        }
    }
    
    
    // MARK: - LÓGICA DE ENVÍO AL RELOJ
    
    func sincronizarReloj() {
        print("📲 Sincronizando...")
        
        let lista = partidosProximos.map { p in
            
            // LÓGICA DE COLORES CORREGIDA:
            // Si el partido tiene color personalizado, usamos ese. Si no, el del equipo.
            let colorL = !p.colorLocalHexPartido.isEmpty ? p.colorLocalHexPartido : (p.equipoLocal?.colorHex ?? "#000000")
            let colorV = !p.colorVisitanteHexPartido.isEmpty ? p.colorVisitanteHexPartido : (p.equipoVisitante?.colorVisitanteHex ?? "#FFFFFF")
            
            return PartidoReloj(
                id: p.id,
                equipoLocal: p.equipoLocal?.nombre ?? "Local",
                acronimoLocal: p.equipoLocal?.acronimo ?? "LOC",
                colorLocalHex: colorL, // <--- Color correcto
                localEscudoData: comprimirEscudo(p.equipoLocal?.escudoData),
                
                equipoVisitante: p.equipoVisitante?.nombre ?? "Visitante",
                acronimoVisitante: p.equipoVisitante?.acronimo ?? "VIS",
                colorVisitanteHex: colorV, // <--- Color correcto
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

// MARK: - COMPONENTES AUXILIARES

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
                        // Navegación Invisible
                        if esDisputado {
                            // Si ya se jugó -> Vamos al detalle
                            NavigationLink(destination: DetallePartidoView(partido: partido)) {
                                EmptyView()
                            }
                            .opacity(0)
                        } else {
                            // Si es próximo -> Vamos a la Vista Previa
                            NavigationLink(destination: VistaPreviaPartido(partido: partido)) {
                                EmptyView()
                            }
                            .opacity(0)
                        }
                        
                        // La Celda Visual
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

// MARK: - DISEÑOS DE CELDA

struct VistaCeldaProximo: View {
    let partido: Partido
    
    var body: some View {
        VStack(spacing: 12) {
            // CATEGORÍA
            Text(partido.categoria?.nombre.uppercased() ?? "PARTIDO")
                .font(.caption2)
                .bold()
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange)
                .clipShape(Capsule())
            
            // ENFRENTAMIENTO
            HStack(alignment: .center, spacing: 6) {
                // LOCAL
                HStack(spacing: 4) {
                    ImagenEscudo(data: partido.equipoLocal?.escudoData, size: 24)
                    
                    // LÓGICA COLOR: Prioriza el del partido, sino el del equipo
                    Rectangle()
                        .fill((!partido.colorLocalHexPartido.isEmpty ? partido.colorLocalHexPartido : partido.equipoLocal?.colorHex ?? "#000000").toColor())
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
                
                // VISITANTE
                HStack(spacing: 4) {
                    Text(partido.equipoVisitante?.nombre ?? "Visitante")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    // LÓGICA COLOR: Prioriza el del partido, sino el del equipo
                    Rectangle()
                        .fill((!partido.colorVisitanteHexPartido.isEmpty ? partido.colorVisitanteHexPartido : partido.equipoVisitante?.colorVisitanteHex ?? "#FFFFFF").toColor())
                        .frame(width: 4, height: 20)
                        .overlay(Rectangle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                    
                    ImagenEscudo(data: partido.equipoVisitante?.escudoData, size: 24)
                }
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // FECHA Y ESTADIO
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
}

struct VistaCeldaDisputado: View {
    let partido: Partido
    
    var body: some View {
        HStack(spacing: 12) {
            
            // FECHA
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
            
            // CATEGORÍA + EQUIPOS
            VStack(alignment: .leading, spacing: 6) {
                
                Text(partido.categoria?.nombre.uppercased() ?? "-")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .clipShape(Capsule())
                
                // LOCAL
                HStack {
                    Rectangle()
                        .fill((!partido.colorLocalHexPartido.isEmpty ? partido.colorLocalHexPartido : partido.equipoLocal?.colorHex ?? "#000000").toColor())
                        .frame(width: 4, height: 14)
                        .overlay(Rectangle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                    
                    Text(partido.equipoLocal?.nombre ?? "Local")
                        .font(.subheadline)
                        .lineLimit(1)
                }
                
                // VISITANTE
                HStack {
                    Rectangle()
                        .fill((!partido.colorVisitanteHexPartido.isEmpty ? partido.colorVisitanteHexPartido : partido.equipoVisitante?.colorVisitanteHex ?? "#FFFFFF").toColor())
                        .frame(width: 4, height: 14)
                        .overlay(Rectangle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                    
                    Text(partido.equipoVisitante?.nombre ?? "Visitante")
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // RESULTADO
            HStack(spacing: 10) {
                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(partido.golesLocal)").font(.subheadline).monospacedDigit().bold()
                    Text("\(partido.golesVisitante)").font(.subheadline).monospacedDigit().bold()
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.gray.opacity(0.5))
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
}
