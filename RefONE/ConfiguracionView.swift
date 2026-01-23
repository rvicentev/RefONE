import SwiftUI

struct ConfiguracionView: View {
    @AppStorage("nombreUsuario") private var nombreUsuario: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                // Sección para cambiar el nombre que sale en Inicio
                Section("Perfil") {
                    HStack {
                        Text("Nombre:")
                        TextField("Tu nombre", text: $nombreUsuario)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Base de Datos") {
                    NavigationLink(destination: ListaCategoriasView()) {
                        Label("Categorías y Tarifas", systemImage: "eurosign.circle")
                    }
                    NavigationLink(destination: ListaEquiposView()) {
                        Label("Equipos", systemImage: "tshirt")
                    }
                    NavigationLink(destination: ListaEstadiosView()) {
                        Label("Estadios", systemImage: "sportscourt")
                    }
                }
                
                Section("Acerca de") {
                    HStack {
                        Label("Versión", systemImage: "info.circle")
                        Spacer()
                        Text("0.1.4").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Configuración")
        }
    }
}
