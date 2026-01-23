import SwiftUI
import SwiftData

// NOTA: No definimos 'enum RolArbitro' aquí porque ya está en Modelos.swift

struct FormularioPartidoView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    
    // Consultas
    @Query(sort: \Equipo.nombre) private var equipos: [Equipo]
    @Query(sort: \Categoria.nombre) private var categorias: [Categoria]
    
    // Variables de Estado
    @State private var local: Equipo?
    @State private var visitante: Equipo?
    @State private var categoria: Categoria?
    @State private var fecha: Date = Date()
    @State private var desplazamiento: Double = 0.0
    @State private var colorLocalOverride: Color = .black
    @State private var colorVisitanteOverride: Color = .white
    @State private var usarColoresPersonalizados = false
    
    // Usamos el Enum para la UI
    @State private var rol: RolArbitro = .principal
    
    var body: some View {
        NavigationStack {
            Form {
                // --- SECCIÓN 1: DATOS ---
                Section("Detalles del Encuentro") {
                    
                    // SELECTOR DE CATEGORÍA
                    Picker("Categoría", selection: $categoria) {
                        Text("Seleccionar").tag(nil as Categoria?)
                        ForEach(categorias) { cat in
                            Text(cat.nombre).tag(cat as Categoria?)
                        }
                    }
                    .onChange(of: categoria) {
                        // Lógica: Si cambiamos a una categoría que NO permite asistente, forzamos Principal
                        if let cat = categoria, !cat.permiteAsistente {
                            rol = .principal
                        }
                    }
                    
                    DatePicker("Fecha y Hora", selection: $fecha)
                    
                    // LÓGICA CONDICIONAL DEL ROL
                    if let cat = categoria, cat.permiteAsistente {
                        // Si permite asistente, dejamos elegir
                        Picker("Tu Rol", selection: $rol) {
                            ForEach(RolArbitro.allCases) { role in
                                Text(role.rawValue).tag(role)
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        // Si no permite, mostramos texto fijo
                        HStack {
                            Text("Tu Rol")
                            Spacer()
                            Text("Principal (Fijo)")
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                    }
                }
                
                // --- SECCIÓN 2: EQUIPOS ---
                Section("Equipos") {
                    Picker("Equipo Local", selection: $local) {
                        Text("Seleccionar").tag(nil as Equipo?)
                        ForEach(equipos) { equipo in
                            Text(equipo.nombre).tag(equipo as Equipo?)
                        }
                    }
                    
                    Picker("Equipo Visitante", selection: $visitante) {
                        Text("Seleccionar").tag(nil as Equipo?)
                        ForEach(equipos) { equipo in
                            if equipo != local {
                                Text(equipo.nombre).tag(equipo as Equipo?)
                            }
                        }
                    }
                }
                
                Section("Económico") {
                    HStack {
                        Text("Desplazamiento (€)")
                        TextField("0.0", value: $desplazamiento, format: .currency(code: "EUR"))
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section("Equipaciones Hoy") {
                    Toggle("Personalizar Colores", isOn: $usarColoresPersonalizados)
                    
                    if usarColoresPersonalizados {
                        ColorPicker("Color Local", selection: $colorLocalOverride)
                        ColorPicker("Color Visitante", selection: $colorVisitanteOverride)
                    }
                }
                
                // --- SECCIÓN 3: PREVISUALIZACIÓN ---
                Section {
                    VStack(spacing: 15) {
                        Text("VISTA PREVIA")
                            .font(.caption)
                            .tracking(2)
                            .foregroundStyle(.secondary)
                        
                        HStack(alignment: .center, spacing: 20) {
                            // Círculo Local
                            VStack {
                                ImagenEscudoGrande(data: local?.escudoData)
                                Rectangle()
                                    .fill(local?.colorHex.toColor() ?? .gray)
                                    .frame(height: 4)
                                    .frame(maxWidth: 60)
                            }
                            
                            Text("vs")
                                .font(.title)
                                .italic()
                                .foregroundStyle(.secondary)
                            
                            // Círculo Visitante
                            VStack {
                                ImagenEscudoGrande(data: visitante?.escudoData)
                                Rectangle()
                                    .fill(visitante?.colorVisitanteHex.toColor() ?? .gray)
                                    .frame(height: 4)
                                    .frame(maxWidth: 60)
                            }
                        }
                        
                        Divider()
                        
                        VStack(spacing: 5) {
                            Text(categoria?.nombre ?? "Categoría")
                                .font(.headline)
                            
                            // MOSTRAR EL ROL ELEGIDO
                            Text(rol.rawValue.uppercased())
                                .font(.caption2)
                                .bold()
                                .padding(4)
                                .background(rol == .principal ? Color.indigo.opacity(0.2) : Color.orange.opacity(0.2))
                                .foregroundStyle(rol == .principal ? .indigo : .orange)
                                .cornerRadius(4)
                            
                            HStack {
                                Image(systemName: "sportscourt")
                                Text(local?.estadio?.nombre ?? "Estadio Local")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            
                            Text(fecha, format: .dateTime.day().month().year().hour().minute())
                                .font(.footnote)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                } header: {
                    Text("Resumen")
                }
            }
            .navigationTitle("Nuevo Partido")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }
                        .disabled(local == nil || visitante == nil || categoria == nil)
                }
            }
        }
    }
    
    private func guardar() {
        // 1. Validaciones básicas
        guard let cat = categoria, let eqLocal = local, let eqVisitante = visitante else { return }
        let esPrincipal = (rol == .principal)
        
        // 2. Crear objeto Partido en base de datos (iPhone)
        // Usamos el nuevo campo 'costeDesplazamiento'
        let nuevoPartido = Partido(
            fecha: fecha,
            equipoLocal: eqLocal,
            equipoVisitante: eqVisitante,
            categoria: cat,
            actuadoComoPrincipal: esPrincipal,
            costeDesplazamiento: desplazamiento
        )
        
        // 3. Guardar colores personalizados si se activaron
        if usarColoresPersonalizados {
            nuevoPartido.colorLocalHexPartido = colorLocalOverride.toHex() ?? "#000000"
            nuevoPartido.colorVisitanteHexPartido = colorVisitanteOverride.toHex() ?? "#FFFFFF"
        }
        
        // 4. Insertar en SwiftData
        contexto.insert(nuevoPartido)
        
        do {
            try contexto.save()
            
            // --- ENVÍO AL RELOJ ⌚️ ---
            
            // A. Buscamos TODOS los partidos pendientes en la base de datos
            let descriptor = FetchDescriptor<Partido>(
                predicate: #Predicate { $0.finalizado == false },
                sortBy: [SortDescriptor(\.fecha)]
            )
            let partidosPendientes = try contexto.fetch(descriptor)
            
            // B. CONVERSIÓN: [Partido] -> [PartidoReloj]
            // Mapeamos usando EXACTAMENTE los campos de tu struct PartidoReloj
            let listaParaReloj = partidosPendientes.map { p in
                
                // Lógica de colores: Prioridad al color personalizado del partido, si no, el del equipo
                let colorL = !p.colorLocalHexPartido.isEmpty ? p.colorLocalHexPartido : (p.equipoLocal?.colorHex ?? "#000000")
                let colorV = !p.colorVisitanteHexPartido.isEmpty ? p.colorVisitanteHexPartido : (p.equipoVisitante?.colorVisitanteHex ?? "#FFFFFF")
                
                // Creamos el struct que me has pasado en DatosCompartidos
                return PartidoReloj(
                    id: p.id,
                    equipoLocal: p.equipoLocal?.nombre ?? "Local",
                    acronimoLocal: p.equipoLocal?.acronimo ?? "LOC",
                    colorLocalHex: colorL,
                    localEscudoData: p.equipoLocal?.escudoData,
                    
                    equipoVisitante: p.equipoVisitante?.nombre ?? "Visitante",
                    acronimoVisitante: p.equipoVisitante?.acronimo ?? "VIS",
                    colorVisitanteHex: colorV,
                    visitanteEscudoData: p.equipoVisitante?.escudoData,
                    
                    estadio: p.equipoLocal?.estadio?.nombre ?? "Estadio",
                    fecha: p.fecha,
                    categoria: p.categoria?.nombre ?? "General",
                    
                    // NOTA: Asumo que tu modelo Categoria tiene estos campos.
                    // Si no los tiene, cambia p.categoria?.duracionParte por 45
                    duracionParteMinutos: p.categoria?.duracionParteMinutos ?? 45,
                    duracionDescansoMinutos: p.categoria?.duracionDescansoMinutos ?? 15,
                    
                    workoutID: p.workoutID
                )
            }
            
            // C. ENVIAR
            // Tu función se llama 'enviarPartidosAlReloj(_ partidos: ...)' (con guion bajo),
            // así que NO hay que poner la etiqueta 'partidos:' al llamar.
            GestorConectividad.shared.enviarPartidosAlReloj(listaParaReloj)
            
            // --------------------------------
            
            print("✅ Partido guardado y enviado. Colores usados: L(\(usarColoresPersonalizados ? "Personalizado" : "Original"))")
            cerrar()
            
        } catch {
            print("❌ Error al guardar partido: \(error)")
        }
    }
    
    // Helper para escudo grande en preview
    struct ImagenEscudoGrande: View {
        let data: Data?
        var body: some View {
            if let data = data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(Circle())
                    .shadow(radius: 3)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 70, height: 70)
                    .overlay(Image(systemName: "shield.fill").font(.largeTitle).foregroundStyle(.gray.opacity(0.3)))
            }
        }
    }
}
