import Foundation
import SwiftUI

// DTO para sincronización de contexto (iOS -> watchOS)
struct PartidoReloj: Identifiable, Codable {
    var id: UUID
    
    // Metadata Local
    var equipoLocal: String
    var acronimoLocal: String
    var colorLocalHex: String
    var localEscudoData: Data?
    
    // Metadata Visitante
    var equipoVisitante: String
    var acronimoVisitante: String
    var colorVisitanteHex: String
    var visitanteEscudoData: Data?
    
    // Contexto de Partido
    var estadio: String
    var fecha: Date
    var categoria: String
    
    // Configuración de Tiempo
    var duracionParteMinutos: Int
    var duracionDescansoMinutos: Int
    
    // Integración HealthKit
    var workoutID: UUID?
}

extension String {
    // Parser Hex a Color para renderizado UI
    func toColorWatch() -> Color {
        var hexSanitized = self.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        return Color(red: r, green: g, blue: b)
    }
}
