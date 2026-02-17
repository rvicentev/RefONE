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
                HStack {
                    // Bloque de información
                    VStack(alignment: .leading) {
                        Text(categoria.nombre)
                            .font(.headline)
                        Text(categoria.edadJugadores)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Bloque de precio
                    Text(categoria.tarifaPrincipal, format: .currency(code: "EUR"))
                        .bold()
                        .foregroundStyle(.green)
                }
                // Acciones de fila
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
        .navigationTitle("Categorías")
        .toolbar {
            Button("Crear", systemImage: "plus") {
                esModoCreacion = true
            }
        }
        // Modales de formulario
        .sheet(isPresented: $esModoCreacion) {
            FormularioCategoriaView(categoriaAEditar: nil)
        }
        .sheet(item: $categoriaSeleccionada) { categoria in
            FormularioCategoriaView(categoriaAEditar: categoria)
        }
    }
}
