import SwiftUI

struct ConfiguracionView: View {
    // Persistencia local - Perfil
    @AppStorage("nombreUsuario") private var nombreUsuario: String = ""
    
    // Persistencia local - Zonas Cardíacas
    @AppStorage("fcMax") private var fcMax: Double = 190.0
    @AppStorage("limiteZ1") private var limiteZ1: Double = 0.60
    @AppStorage("limiteZ2") private var limiteZ2: Double = 0.70
    @AppStorage("limiteZ3") private var limiteZ3: Double = 0.80
    @AppStorage("limiteZ4") private var limiteZ4: Double = 0.90
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Perfil") {
                    HStack {
                        Text("Nombre:")
                        TextField("Tu nombre", text: $nombreUsuario)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // MARK: - NUEVA SECCIÓN ZONAS CARDÍACAS
                Section("Salud y Rendimiento") {
                    VStack(alignment: .leading) {
                        Text("Frecuencia Cardíaca Máxima (FC Max)")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Text("\(Int(fcMax)) bpm")
                                .font(.title3).bold().foregroundStyle(.red)
                            Slider(value: $fcMax, in: 150...220, step: 1)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    DisclosureGroup("Configurar Intervalos de Zonas") {
                        VStack(spacing: 15) {
                            Text("Ajusta el límite superior de cada zona (% de FC Max).")
                                .font(.caption2).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            ControlZona(nombre: "Zona 1 (Recuperación)", valor: $limiteZ1, color: .blue, rango: 0.5...limiteZ2)
                            ControlZona(nombre: "Zona 2 (Aeróbico Suave)", valor: $limiteZ2, color: .green, rango: limiteZ1...limiteZ3)
                            ControlZona(nombre: "Zona 3 (Aeróbico Medio)", valor: $limiteZ3, color: .yellow, rango: limiteZ2...limiteZ4)
                            ControlZona(nombre: "Zona 4 (Umbral)", valor: $limiteZ4, color: .orange, rango: limiteZ3...0.99)
                            
                            HStack {
                                Circle().fill(Color.red).frame(width: 8, height: 8)
                                Text("Zona 5 (Máximo)")
                                Spacer()
                                Text("> \(Int(fcMax * limiteZ4)) bpm")
                            }
                            .font(.caption).bold()
                        }
                        .padding(.top, 10)
                    }
                }
                
                // Vistas de gestión de maestros
                Section("Base de Datos") {
                    NavigationLink(destination: ListaCategoriasView()) {
                        Label("Categorías y Dietas", systemImage: "eurosign.circle")
                    }
                    
                    NavigationLink(destination: ListaEquiposView()) {
                        Label("Equipos", systemImage: "tshirt")
                    }
                    
                    NavigationLink(destination: ListaEstadiosView()) {
                        Label("Campos", systemImage: "sportscourt")
                    }
                }
                
                Section("Acerca de") {
                    HStack {
                        Label("Versión", systemImage: "info.circle")
                        Spacer()
                        Text("0.1.5")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Configuración")
        }
    }
}

// Subvista auxiliar para los Sliders de zonas
struct ControlZona: View {
    let nombre: String
    @Binding var valor: Double
    let color: Color
    let rango: ClosedRange<Double>
    
    // Leemos la FC Max para mostrar el cálculo en tiempo real
    @AppStorage("fcMax") private var fcMax: Double = 190.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(nombre).font(.caption).bold()
                Spacer()
                Text("\(Int(valor * 100))%").font(.caption).foregroundStyle(.secondary)
                Text("(\(Int(fcMax * valor)) bpm)").font(.caption).bold().monospacedDigit()
            }
            Slider(value: $valor, in: rango)
        }
    }
}
