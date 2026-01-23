import SwiftUI
import SwiftData

@main
struct RefONEApp: App {
    init() {
        _ = GestorConectividad.shared
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                // Pestaña 1: Inicio
                InicioView()
                    .tabItem {
                        Label("Inicio", systemImage: "house.fill")
                    }
                
                // Pestaña 2: Partidos
                NavigationStack {
                    ListaPartidosView()
                }
                .tabItem {
                    Label("Partidos", systemImage: "soccerball")
                }
                
                // Pestaña 3: Estadísticas (Placeholder)
                EstadisticasView()
                    .tabItem {
                        Label("Estadísticas", systemImage: "chart.bar.xaxis")
                    }
                
                // Pestaña 4: Configuración
                ConfiguracionView()
                    .tabItem {
                        Label("Configuración", systemImage: "gearshape.fill")
                    }
            }
            // Color de acento global (Naranja RefONE)
            .tint(.orange)
        }
        .modelContainer(for: [
            Categoria.self,
            Equipo.self,
            Estadio.self,
            Partido.self
        ])
    }
}
