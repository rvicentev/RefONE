import Foundation
import SwiftData
import SwiftUI

// MARK: - ENUMERADOS HELPER
// Lo hacemos Identifiable para que funcione en los Pickers de SwiftUI
enum RolArbitro: String, CaseIterable, Identifiable, Codable {
    case principal = "Principal"
    case asistente = "Asistente"
    // case cuarto = "Cuarto Árbitro" // Puedes descomentarlo si lo usas en el futuro
    
    var id: String { self.rawValue }
}

// MARK: - MODELO: CATEGORÍA
@Model
class Categoria {
    var id: UUID
    var nombre: String
    var edadJugadores: String // Ej: "16-18 años" o "Juvenil"
    
    // Economía
    var tarifaPrincipal: Double
    
    // Configuración de Asistente
    var permiteAsistente: Bool
    var tarifaAsistente: Double
    
    // Tiempos
    var duracionParteMinutos: Int
    var duracionDescansoMinutos: Int
    
    // Relación
    @Relationship(deleteRule: .cascade, inverse: \Partido.categoria)
    var partidos: [Partido]? = []
    
    init(nombre: String,
         edadJugadores: String,
         tarifaPrincipal: Double,
         permiteAsistente: Bool = false,
         tarifaAsistente: Double = 0.0,
         duracionParteMinutos: Int = 45,
         duracionDescansoMinutos: Int = 15) {
        
        self.id = UUID()
        self.nombre = nombre
        self.edadJugadores = edadJugadores
        self.tarifaPrincipal = tarifaPrincipal
        self.permiteAsistente = permiteAsistente
        self.tarifaAsistente = tarifaAsistente
        self.duracionParteMinutos = duracionParteMinutos
        self.duracionDescansoMinutos = duracionDescansoMinutos
    }
}

// MARK: - MODELO: EQUIPO
@Model
class Equipo {
    var id: UUID
    var nombre: String
    var acronimo: String
    var colorHex: String
    var colorVisitanteHex: String
    @Attribute(.externalStorage) var escudoData: Data?
    
    // Relación con Estadio
    var estadio: Estadio?
    
    init(nombre: String, acronimo: String, colorHex: String, colorVisitanteHex: String, escudoData: Data? = nil, estadio: Estadio? = nil) {
        self.id = UUID()
        self.nombre = nombre
        self.acronimo = acronimo
        self.colorHex = colorHex
        self.colorVisitanteHex = colorVisitanteHex
        self.escudoData = escudoData
        self.estadio = estadio
    }
}

// MARK: - MODELO: ESTADIO
@Model
class Estadio {
    var id: UUID
    var nombre: String
    var lugar: String
    
    @Relationship(deleteRule: .nullify, inverse: \Equipo.estadio)
    var equiposLocales: [Equipo]? = []
    
    init(nombre: String, lugar: String) {
        self.id = UUID()
        self.nombre = nombre
        self.lugar = lugar
    }
}

// MARK: - MODELO: PARTIDO
@Model
class Partido {
    var id: UUID
    var fecha: Date
    
    // Relaciones
    var categoria: Categoria?
    var equipoLocal: Equipo?
    var equipoVisitante: Equipo?
    
    var distanciaRecorrida: Double = 0.0 // En metros
    
    // Configuración del Árbitro
    var actuadoComoPrincipal: Bool = true
    
    // Estado del Partido
    var golesLocal: Int = 0
    var golesVisitante: Int = 0
    var finalizado: Bool = false
    var workoutID: UUID?
    
    // --- NUEVOS CAMPOS ---
    var caloriasQuemadas: Double = 0.0   // Para guardar lo de Estadísticas
    var costeDesplazamiento: Double = 0.0 // Dinero extra
    
    // Colores específicos para ESTE partido
    var colorLocalHexPartido: String = ""
    var colorVisitanteHexPartido: String = ""
    
    // --- INIT CORREGIDO ---
    init(fecha: Date,
         equipoLocal: Equipo,
         equipoVisitante: Equipo,
         categoria: Categoria,
         actuadoComoPrincipal: Bool = true,
         distanciaRecorrida: Double = 0.0,
         // 👇 AQUÍ FALTABA ESTE PARÁMETRO:
         costeDesplazamiento: Double = 0.0) {
        
        self.id = UUID()
        self.fecha = fecha
        self.equipoLocal = equipoLocal
        self.equipoVisitante = equipoVisitante
        self.categoria = categoria
        self.actuadoComoPrincipal = actuadoComoPrincipal
        self.distanciaRecorrida = distanciaRecorrida
        
        // Ahora sí existe la variable 'costeDesplazamiento' que entra por el init
        self.costeDesplazamiento = costeDesplazamiento
        
        // Valores por defecto
        self.golesLocal = 0
        self.golesVisitante = 0
        self.finalizado = false
        self.workoutID = nil
        self.caloriasQuemadas = 0.0
        self.colorLocalHexPartido = ""
        self.colorVisitanteHexPartido = ""
    }
}

// MARK: - EXTENSIONES VISUALES

extension String {
    func toColor() -> Color {
        var hexSanitized = self.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let length = hexSanitized.count
        let r, g, b: Double
        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
        } else {
            r = 0; g = 0; b = 0
        }
        return Color(red: r, green: g, blue: b)
    }
}

extension Color {
    func toHex() -> String {
        // Conversión segura usando UIColor
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        
        let r = components[0]
        let g = components.count >= 2 ? components[1] : r
        let b = components.count >= 3 ? components[2] : r
        
        return String(format: "#%02lX%02lX%02lX",
                      lroundf(Float(r) * 255),
                      lroundf(Float(g) * 255),
                      lroundf(Float(b) * 255))
    }
}
