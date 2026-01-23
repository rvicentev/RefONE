import SwiftUI
import _SwiftData_SwiftUI

struct ListaCategoriasView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Categoria.nombre) private var categorias: [Categoria]
    
    // Estado para saber qué categoría estamos creando o editando
    @State private var categoriaSeleccionada: Categoria?
    @State private var esModoCreacion = false
    
    var body: some View {
        List {
            ForEach(categorias) { categoria in
                HStack {
                    VStack(alignment: .leading) {
                        Text(categoria.nombre)
                            .font(.headline)
                        Text(categoria.edadJugadores)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(categoria.tarifaPrincipal, format: .currency(code: "EUR"))
                        .bold()
                        .foregroundStyle(.green)
                }
                // AQUÍ ESTÁN LAS ACCIONES DE DESLIZAR
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    // Botón Borrar (Rojo)
                    Button(role: .destructive) {
                        contexto.delete(categoria)
                    } label: {
                        Label("Borrar", systemImage: "trash")
                    }
                    
                    // Botón Editar (Naranja)
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
        // Hoja para CREAR (Nueva)
        .sheet(isPresented: $esModoCreacion) {
            FormularioCategoriaView(categoriaAEditar: nil)
        }
        // Hoja para EDITAR (Cuando seleccionamos una)
        .sheet(item: $categoriaSeleccionada) { categoria in
            FormularioCategoriaView(categoriaAEditar: categoria)
        }
    }
}
