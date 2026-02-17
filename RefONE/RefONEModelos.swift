import Foundation
import SwiftData
import SwiftUI

// MARK: - Enums

enum RolArbitro: String, CaseIterable, Identifiable, Codable {
    case principal = "Principal"
    case asistente = "Asistente"
    
    var id: String { self.rawValue }
}

// MARK: - Models

@Model
class Categoria {
    var id: UUID
    var nombre: String
    var edadJugadores: String
    
    // Financial Config
    var tarifaPrincipal: Double
    var tarifaAsistente: Double
    var permiteAsistente: Bool
    
    // Time Rules
    var duracionParteMinutos: Int
    var duracionDescansoMinutos: Int
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Partido.categoria)
    var partidos: [Partido]? = []
    
    init(
        nombre: String,
        edadJugadores: String,
        tarifaPrincipal: Double,
        permiteAsistente: Bool = false,
        tarifaAsistente: Double = 0.0,
        duracionParteMinutos: Int = 45,
        duracionDescansoMinutos: Int = 15
    ) {
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

@Model
class Equipo {
    var id: UUID
    var nombre: String
    var acronimo: String
    
    // Visual Identity
    var colorHex: String
    var colorVisitanteHex: String
    @Attribute(.externalStorage) var escudoData: Data?
    
    // Relationships
    var estadio: Estadio?
    
    init(
        nombre: String,
        acronimo: String,
        colorHex: String,
        colorVisitanteHex: String,
        escudoData: Data? = nil,
        estadio: Estadio? = nil
    ) {
        self.id = UUID()
        self.nombre = nombre
        self.acronimo = acronimo
        self.colorHex = colorHex
        self.colorVisitanteHex = colorVisitanteHex
        self.escudoData = escudoData
        self.estadio = estadio
    }
}

@Model
class Estadio {
    var id: UUID
    var nombre: String
    var lugar: String
    
    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \Equipo.estadio)
    var equiposLocales: [Equipo]? = []
    
    init(nombre: String, lugar: String) {
        self.id = UUID()
        self.nombre = nombre
        self.lugar = lugar
    }
}

@Model
class Partido {
    var id: UUID
    var fecha: Date
    
    // Relationships
    var categoria: Categoria?
    var equipoLocal: Equipo?
    var equipoVisitante: Equipo?
    
    // Performance Metrics
    var distanciaRecorrida: Double = 0.0
    var caloriasQuemadas: Double = 0.0
    var workoutID: UUID?
    
    // Match State
    var golesLocal: Int = 0
    var golesVisitante: Int = 0
    var finalizado: Bool = false
    
    // Configuration
    var actuadoComoPrincipal: Bool = true
    var costeDesplazamiento: Double = 0.0
    
    // Visual Overrides
    var colorLocalHexPartido: String = ""
    var colorVisitanteHexPartido: String = ""
    
    init(
        fecha: Date,
        equipoLocal: Equipo,
        equipoVisitante: Equipo,
        categoria: Categoria,
        actuadoComoPrincipal: Bool = true,
        distanciaRecorrida: Double = 0.0,
        costeDesplazamiento: Double = 0.0
    ) {
        self.id = UUID()
        self.fecha = fecha
        self.equipoLocal = equipoLocal
        self.equipoVisitante = equipoVisitante
        self.categoria = categoria
        self.actuadoComoPrincipal = actuadoComoPrincipal
        self.distanciaRecorrida = distanciaRecorrida
        self.costeDesplazamiento = costeDesplazamiento
        
        // Defaults
        self.golesLocal = 0
        self.golesVisitante = 0
        self.finalizado = false
        self.workoutID = nil
        self.caloriasQuemadas = 0.0
        self.colorLocalHexPartido = ""
        self.colorVisitanteHexPartido = ""
    }
}

// MARK: - Extensions

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
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        
        let r = components[0]
        let g = components.count >= 2 ? components[1] : r
        let b = components.count >= 3 ? components[2] : r
        
        return String(
            format: "#%02lX%02lX%02lX",
            lroundf(Float(r) * 255),
            lroundf(Float(g) * 255),
            lroundf(Float(b) * 255)
        )
    }
}
