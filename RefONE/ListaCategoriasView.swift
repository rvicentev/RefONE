import SwiftUI
import SwiftData

struct ListaCategoriasView: View {
    // Contexto de datos y consulta
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Categoria.nombre) private var categorias: [Categoria]
    
    // Estado de navegación
    @State private var categoriaSeleccionada: Categoria?
    @State private var esModoCreacion = false
    
    var body: some View {
        List {
            ForEach(categorias) { categoria in
                // MARK: - BLOQUE DE CATEGORÍA (TARJETA)
                VStack(alignment: .leading, spacing: 14) {
                    
                    // Fila 1: Nombre, Etiquetas (Edad y Tiempo) y Logo
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(categoria.nombre)
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            // Fila de etiquetas (Pills)
                            HStack(spacing: 8) {
                                // Etiqueta de Edad
                                if !categoria.edadJugadores.isEmpty {
                                    Text(categoria.edadJugadores)
                                        .font(.caption2)
                                        .bold()
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.15))
                                        .foregroundStyle(.blue)
                                        .clipShape(Capsule())
                                }
                                
                                // Etiqueta de Tiempo (Duración de la parte)
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.fill")
                                    Text("\(categoria.duracionParteMinutos)'")
                                }
                                .font(.caption2)
                                .bold()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.15))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "eurosign.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green.opacity(0.8))
                    }
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    // Fila 2: Precios (Principal y Asistente condicional)
                    HStack {
                        // Tarifa Principal
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PRINCIPAL")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            
                            Text(categoria.tarifaPrincipal, format: .currency(code: "EUR"))
                                .font(.headline)
                                .foregroundStyle(.green)
                        }
                        
                        Spacer()
                        
                        // Tarifa Asistente (Basado en el booleano 'permiteAsistente')
                        if categoria.permiteAsistente {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("ASISTENTE")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                
                                Text(categoria.tarifaAsistente, format: .currency(code: "EUR"))
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                            }
                        } else {
                            Text("Sin Asistentes")
                                .font(.caption)
                                .italic()
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding() // Padding interior de la tarjeta
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
                // 👇 Modificadores de lista para crear el efecto flotante
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                
                // MARK: - Acciones de fila
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        contexto.delete(categoria)
                    } label: {
                        Label("Borrar", systemImage: "trash")
                    }
                    
                    Button {
                        categoriaSeleccionada = categoria
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
            }
        }
        .listStyle(.plain) // Quita el estilo de caja agrupadora nativo
        .background(Color(UIColor.systemGroupedBackground)) // Fondo para contraste
        .navigationTitle("Categorías y Dietas")
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
        // Modales de formulario
        .sheet(isPresented: $esModoCreacion) {
            FormularioCategoriaView(categoriaAEditar: nil)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $categoriaSeleccionada) { categoria in
            FormularioCategoriaView(categoriaAEditar: categoria)
                .presentationDetents([.medium, .large])
        }
        // Estado vacío
        .overlay {
            if categorias.isEmpty {
                ContentUnavailableView(
                    "Sin Categorías",
                    systemImage: "eurosign.circle",
                    description: Text("Añade las categorías y tarifas que arbitras habitualmente.")
                )
            }
        }
    }
}
