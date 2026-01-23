import Foundation
import SwiftUI

// Este struct sirve para enviar los datos del móvil al reloj de forma sencilla
struct PartidoReloj: Identifiable, Codable {
    var id: UUID
    var equipoLocal: String
    var acronimoLocal: String
    var colorLocalHex: String
    var localEscudoData: Data?
    
    var equipoVisitante: String
    var acronimoVisitante: String
    var colorVisitanteHex: String
    var visitanteEscudoData: Data?
    
    var estadio: String
    var fecha: Date
    var categoria: String
    
    var duracionParteMinutos: Int
    var duracionDescansoMinutos: Int
    
    var workoutID: UUID?
}

// Extensión para facilitar la conversión de Hex a Color en el reloj también
extension String {
    func toColorWatch() -> Color {
        // Copia simplificada de tu extensión anterior para el Watch
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
