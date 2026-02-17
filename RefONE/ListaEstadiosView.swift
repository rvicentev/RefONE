import SwiftUI
import SwiftData

struct ListaEstadiosView: View {
    // Contexto de datos
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Estadio.nombre) private var estadios: [Estadio]
    
    // Gestión de estado y navegación
    @State private var estadioSeleccionado: Estadio?
    @State private var esModoCreacion = false
    
    var body: some View {
        List {
            ForEach(estadios) { estadio in
                HStack {
                    // Información Principal
                    VStack(alignment: .leading) {
                        Text(estadio.nombre)
                            .font(.headline)
                        Text(estadio.lugar)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Relación: Equipos Locales (Scroll Horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            if let equipos = estadio.equiposLocales {
                                ForEach(equipos) { equipo in
                                    Text(equipo.acronimo)
                                        .font(.caption)
                                        .bold()
                                        .padding(4)
                                        .background(Color.gray.opacity(0.1))
                                        .foregroundStyle(.gray)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 100, alignment: .trailing)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        contexto.delete(estadio)
                    } label: {
                        Label("Borrar", systemImage: "trash")
                    }
                    
                    Button {
                        estadioSeleccionado = estadio
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
            }
        }
        .navigationTitle("Estadios")
        .toolbar {
            Button("Crear", systemImage: "plus") {
                esModoCreacion = true
            }
        }
        .sheet(isPresented: $esModoCreacion) {
            FormularioEstadioView(estadioAEditar: nil)
        }
        .sheet(item: $estadioSeleccionado) { estadio in
            FormularioEstadioView(estadioAEditar: estadio)
        }
    }
}

// MARK: - Formulario Estadio

struct FormularioEstadioView: View {
    // Inyección de dependencias
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    
    // Parámetro de entrada (Opcional para edición)
    var estadioAEditar: Estadio?
    
    // Estado local
    @State private var nombre: String = ""
    @State private var lugar: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Datos del Estadio") {
                    TextField("Nombre (Ej: Camp Nou)", text: $nombre)
                    TextField("Lugar (Ej: Barcelona)", text: $lugar)
                }
            }
            .navigationTitle(estadioAEditar == nil ? "Nuevo Estadio" : "Editar Estadio")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }
                        .disabled(nombre.isEmpty)
                }
            }
            .onAppear {
                if let estadio = estadioAEditar {
                    nombre = estadio.nombre
                    lugar = estadio.lugar
                }
            }
        }
    }
    
    private func guardar() {
        if let estadio = estadioAEditar {
            // Update flow
            estadio.nombre = nombre
            estadio.lugar = lugar
        } else {
            // Create flow
            let nuevoEstadio = Estadio(nombre: nombre, lugar: lugar)
            contexto.insert(nuevoEstadio)
        }
        cerrar()
    }
}
