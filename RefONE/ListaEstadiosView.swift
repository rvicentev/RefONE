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
                // MARK: - BLOQUE DE ESTADIO (TARJETA)
                VStack(alignment: .leading, spacing: 12) {
                    
                    // Fila 1: Nombre y Logo
                    HStack(alignment: .top) {
                        Text(estadio.nombre)
                            .font(.title3) // Un poco más grande para el bloque
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Image(systemName: "sportscourt.fill")
                            .font(.title2)
                            .foregroundStyle(.green.opacity(0.8)) // Un toque de color césped
                    }
                    
                    // Fila 2: Ubicación
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.red.opacity(0.8))
                        
                        Text(estadio.lugar.isEmpty ? "Ubicación sin definir" : estadio.lugar)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Fila 3: Equipos Locales
                    if let equipos = estadio.equiposLocales, !equipos.isEmpty {
                        // Una línea muy sutil DENTRO de la tarjeta para separar los equipos
                        Divider()
                            .padding(.vertical, 2)
                        
                        HStack {
                            Text("Equipos:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(equipos) { equipo in
                                        Text(equipo.acronimo)
                                            .font(.caption2)
                                            .bold()
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.15))
                                            .foregroundStyle(.blue)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    } else {
                        // Estado vacío para equipos
                        Text("Ningún equipo local vinculado")
                            .font(.caption)
                            .italic()
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                    }
                }
                .padding() // Padding interior de la tarjeta
                .background(Color(UIColor.secondarySystemGroupedBackground)) // Color de fondo adaptable (claro/oscuro)
                .clipShape(RoundedRectangle(cornerRadius: 16)) // Bordes muy redondeados
                .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2) // Sombra sutil
                // 👇 Modificadores clave para convertir la lista en bloques
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)) // Separación entre los bloques
                
                // MARK: - Acciones de Celda
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
        .listStyle(.plain) // Quitamos el estilo por defecto para que los bloques destaquen
        .background(Color(UIColor.systemGroupedBackground)) // Fondo gris clarito detrás de las tarjetas
        .navigationTitle("Campos y Estadios")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    esModoCreacion = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $esModoCreacion) {
            FormularioEstadioView(estadioAEditar: nil)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $estadioSeleccionado) { estadio in
            FormularioEstadioView(estadioAEditar: estadio)
                .presentationDetents([.medium, .large])
        }
        .overlay {
            if estadios.isEmpty {
                ContentUnavailableView(
                    "Sin Estadios",
                    systemImage: "sportscourt",
                    description: Text("Aún no has añadido ningún campo a tu base de datos.")
                )
            }
        }
    }
}

// MARK: - Formulario Estadio

struct FormularioEstadioView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    
    var estadioAEditar: Estadio?
    
    @State private var nombre: String = ""
    @State private var lugar: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre (Ej: Nuevo Vivero)", text: $nombre)
                    TextField("Ubicación (Ej: Badajoz)", text: $lugar)
                } header: {
                    Text("Datos del Campo")
                } footer: {
                    Text("Añade el nombre del recinto y la localidad donde se encuentra.")
                }
            }
            .navigationTitle(estadioAEditar == nil ? "Nuevo Campo" : "Editar Campo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }
                        .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                        .bold()
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
            estadio.nombre = nombre
            estadio.lugar = lugar
        } else {
            let nuevoEstadio = Estadio(nombre: nombre, lugar: lugar)
            contexto.insert(nuevoEstadio)
        }
        cerrar()
    }
}
