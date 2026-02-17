import SwiftUI
import SwiftData
import PhotosUI

struct ListaEquiposView: View {
    // Contexto de datos
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Equipo.nombre) private var equipos: [Equipo]
    
    // Gestión de navegación y estado
    @State private var equipoSeleccionado: Equipo?
    @State private var esModoCreacion = false
    
    var body: some View {
        List {
            ForEach(equipos) { equipo in
                HStack(spacing: 12) {
                    // Indicadores visuales de color
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(equipo.colorHex.toColor())
                            .frame(width: 4)
                        Rectangle()
                            .fill(equipo.colorVisitanteHex.toColor())
                            .frame(width: 4)
                    }
                    .frame(width: 8)
                    .cornerRadius(2)
                    .padding(.vertical, 4)
                    
                    // Renderizado de escudo
                    if let data = equipo.escudoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    } else {
                        Image(systemName: "shield.fill")
                            .resizable()
                            .foregroundStyle(.gray.opacity(0.3))
                            .frame(width: 30, height: 35)
                            .padding(5)
                    }
                    
                    // Información textual
                    Text(equipo.nombre)
                        .font(.headline)
                        .padding(.leading, 4)
                    
                    Spacer()
                    
                    // Badge de acrónimo
                    Text(equipo.acronimo)
                        .font(.subheadline)
                        .monospaced()
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        contexto.delete(equipo)
                    } label: {
                        Label("Borrar", systemImage: "trash")
                    }
                    
                    Button {
                        equipoSeleccionado = equipo
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
            }
        }
        .navigationTitle("Equipos")
        .toolbar {
            Button("Crear", systemImage: "plus") {
                esModoCreacion = true
            }
        }
        .sheet(isPresented: $esModoCreacion) {
            FormularioEquipoView(equipoAEditar: nil)
        }
        .sheet(item: $equipoSeleccionado) { equipo in
            FormularioEquipoView(equipoAEditar: equipo)
        }
    }
}

// MARK: - Formulario de Edición/Creación

struct FormularioEquipoView: View {
    // Inyección de dependencias
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    
    // Consultas relacionadas
    @Query(sort: \Estadio.nombre) private var estadiosDisponibles: [Estadio]
    
    // Parámetro de entrada
    var equipoAEditar: Equipo?
    
    // Estado local del formulario
    @State private var nombre: String = ""
    @State private var acronimo: String = ""
    @State private var colorLocal: Color = .blue
    @State private var colorVisitante: Color = .white
    @State private var itemSeleccionado: PhotosPickerItem? = nil
    @State private var imagenData: Data? = nil
    @State private var estadioSeleccionado: Estadio?
    
    // Control de foco y UX
    @FocusState private var focoEnAcronimo: Bool
    @State private var usuarioHaEditadoAcronimo = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Sección de identidad visual
                Section("Identidad") {
                    HStack {
                        PhotosPicker(selection: $itemSeleccionado, matching: .images) {
                            if let data = imagenData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 70, height: 70)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 70, height: 70)
                                    Image(systemName: "camera.fill")
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                        .onChange(of: itemSeleccionado) { cargarImagen() }
                        
                        VStack(alignment: .leading) {
                            TextField("Nombre del Equipo", text: $nombre)
                                .font(.headline)
                                .onChange(of: nombre) { actualizarAcronimoAutomaticamente() }
                            
                            Text("Toca para añadir escudo")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 10)
                    }
                    .padding(.vertical, 5)
                }
                
                // Configuración de metadatos
                Section("Detalles") {
                    HStack {
                        Text("Acrónimo")
                        Spacer()
                        TextField("ABC", text: $acronimo)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.characters)
                            .frame(width: 80)
                            .focused($focoEnAcronimo)
                            .onChange(of: acronimo) {
                                if focoEnAcronimo { usuarioHaEditadoAcronimo = true }
                            }
                    }
                    
                    HStack {
                        ColorPicker("Local", selection: $colorLocal).labelsHidden()
                        Text("Local").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("Visitante").font(.caption).foregroundStyle(.secondary)
                        ColorPicker("Visitante", selection: $colorVisitante).labelsHidden()
                    }
                }
                
                // Relación con Estadio
                Section("Sede") {
                    if estadiosDisponibles.isEmpty {
                        Text("No hay estadios creados")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        Picker("Estadio Local", selection: $estadioSeleccionado) {
                            Text("Ninguno").tag(nil as Estadio?)
                            ForEach(estadiosDisponibles) { estadio in
                                Text(estadio.nombre).tag(estadio as Estadio?)
                            }
                        }
                    }
                }
            }
            .navigationTitle(equipoAEditar == nil ? "Nuevo Equipo" : "Editar Equipo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }
                        .disabled(nombre.isEmpty)
                }
            }
            .onAppear { cargarDatosSiEsEdicion() }
        }
    }
    
    // MARK: - Lógica de Negocio
    
    private func actualizarAcronimoAutomaticamente() {
        if usuarioHaEditadoAcronimo { return }
        if nombre.isEmpty {
            acronimo = ""
            return
        }
        let letras = nombre.prefix(3).uppercased()
        acronimo = String(letras)
    }
    
    private func cargarImagen() {
        Task {
            if let data = try? await itemSeleccionado?.loadTransferable(type: Data.self) {
                await MainActor.run {
                    imagenData = data
                }
            }
        }
    }
    
    private func cargarDatosSiEsEdicion() {
        guard let equipo = equipoAEditar else { return }
        
        nombre = equipo.nombre
        acronimo = equipo.acronimo
        colorLocal = equipo.colorHex.toColor()
        colorVisitante = equipo.colorVisitanteHex.toColor()
        imagenData = equipo.escudoData
        estadioSeleccionado = equipo.estadio
        usuarioHaEditadoAcronimo = true
    }
    
    private func guardar() {
        let hexLocal = colorLocal.toHex()
        let hexVisitante = colorVisitante.toHex()
        let acronimoFinal = acronimo.isEmpty ? String(nombre.prefix(3).uppercased()) : acronimo
        
        if let equipo = equipoAEditar {
            // Update flow
            equipo.nombre = nombre
            equipo.acronimo = acronimoFinal
            equipo.colorHex = hexLocal
            equipo.colorVisitanteHex = hexVisitante
            equipo.escudoData = imagenData
            equipo.estadio = estadioSeleccionado
        } else {
            // Create flow
            let nuevoEquipo = Equipo(
                nombre: nombre,
                acronimo: acronimoFinal,
                colorHex: hexLocal,
                colorVisitanteHex: hexVisitante,
                escudoData: imagenData,
                estadio: estadioSeleccionado
            )
            contexto.insert(nuevoEquipo)
        }
        
        do {
            try contexto.save()
            cerrar()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}
