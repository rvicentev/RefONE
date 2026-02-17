import SwiftUI
import UIKit
import SwiftData

struct FormularioCategoriaView: View {
    // Contexto y Navegación
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    
    // Inyección de dependencia (Nil = Creación, Valor = Edición)
    var categoriaAEditar: Categoria?
    
    // Estado del Formulario
    @State private var nombre: String = ""
    @State private var edadJugadores: String = ""
    @State private var tarifaPrincipal: Double = 0.0
    
    // Lógica de Asistente
    @State private var permiteAsistente: Bool = false
    @State private var tarifaAsistente: Double = 0.0
    
    // Configuración de Tiempo
    @State private var duracionParte: Int = 45
    @State private var duracionDescanso: Int = 15
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Datos Básicos") {
                    TextField("Nombre (Ej: Senior)", text: $nombre)
                    TextField("Edad (Ej: +18)", text: $edadJugadores)
                }
                
                Section("Honorarios") {
                    TextField("Tarifa Principal", value: $tarifaPrincipal, format: .currency(code: "EUR"))
                        .keyboardType(.decimalPad)
                }
                
                Section("Rol de Asistente") {
                    Toggle("¿Puede actuar como asistente?", isOn: $permiteAsistente)
                    
                    if permiteAsistente {
                        TextField("Tarifa Asistente", value: $tarifaAsistente, format: .currency(code: "EUR"))
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section("Reglas de Tiempo (Minutos)") {
                    HStack {
                        Text("Duración Parte")
                        Spacer()
                        TextField("Min", value: $duracionParte, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                        Text("min")
                    }
                    
                    HStack {
                        Text("Duración Descanso")
                        Spacer()
                        TextField("Min", value: $duracionDescanso, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                        Text("min")
                    }
                }
            }
            .navigationTitle(categoriaAEditar == nil ? "Nueva Categoría" : "Editar Categoría")
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
                cargarDatosSiEsEdicion()
            }
        }
    }
    
    private func cargarDatosSiEsEdicion() {
        guard let categoria = categoriaAEditar else { return }
        
        nombre = categoria.nombre
        edadJugadores = categoria.edadJugadores
        tarifaPrincipal = categoria.tarifaPrincipal
        permiteAsistente = categoria.permiteAsistente
        tarifaAsistente = categoria.tarifaAsistente
        duracionParte = categoria.duracionParteMinutos
        duracionDescanso = categoria.duracionDescansoMinutos
    }
    
    private func guardar() {
        if let categoria = categoriaAEditar {
            // Update
            categoria.nombre = nombre
            categoria.edadJugadores = edadJugadores
            categoria.tarifaPrincipal = tarifaPrincipal
            categoria.permiteAsistente = permiteAsistente
            categoria.tarifaAsistente = permiteAsistente ? tarifaAsistente : 0.0
            categoria.duracionParteMinutos = duracionParte
            categoria.duracionDescansoMinutos = duracionDescanso
        } else {
            // Create
            let nuevaCategoria = Categoria(
                nombre: nombre,
                edadJugadores: edadJugadores,
                tarifaPrincipal: tarifaPrincipal,
                permiteAsistente: permiteAsistente,
                tarifaAsistente: permiteAsistente ? tarifaAsistente : 0.0,
                duracionParteMinutos: duracionParte,
                duracionDescansoMinutos: duracionDescanso
            )
            contexto.insert(nuevaCategoria)
        }
        cerrar()
    }
}
