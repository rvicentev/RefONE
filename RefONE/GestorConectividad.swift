import Foundation
import WatchConnectivity
import SwiftUI
import Combine

class GestorConectividad: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = GestorConectividad()
    
    // Local data persistence
    @Published var partidosRecibidos: [PartidoReloj] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(partidosRecibidos) {
                UserDefaults.standard.set(data, forKey: "partidos_cache")
            }
        }
    }
    
    override init() {
        super.init()
        
        // Hydrate state from cache
        if let data = UserDefaults.standard.data(forKey: "partidos_cache"),
           let saved = try? JSONDecoder().decode([PartidoReloj].self, from: data) {
            self.partidosRecibidos = saved
        }
        
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - Outbound (iOS -> Watch)
    
    func enviarPartidosAlReloj(_ partidos: [PartidoReloj]) {
        if WCSession.default.activationState != .activated {
            WCSession.default.activate()
        }
        
        do {
            let data = try JSONEncoder().encode(partidos)
            let diccionario: [String: Any] = ["partidos": data]
            
            // Context sync
            try WCSession.default.updateApplicationContext(diccionario)
            
            // Immediate messaging attempt
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(diccionario, replyHandler: nil)
            }
            print("[Gestor] Context updated successfully")
        } catch {
            print("[Gestor] Context update failed: \(error)")
        }
    }
    
    // MARK: - Outbound (Watch -> iOS)
    
    func enviarResultadoAlIphone(idPartido: UUID, golesLocal: Int, golesVisitante: Int, workoutID: UUID?) {
        var datos: [String: Any] = [
            "tipo": "resultadoFinal",
            "idPartido": idPartido.uuidString,
            "golesLocal": golesLocal,
            "golesVisitante": golesVisitante,
            "fechaFin": Date().timeIntervalSince1970
        ]
        
        if let wID = workoutID {
            datos["workoutID"] = wID.uuidString
        }
        
        // Background transfer queue
        WCSession.default.transferUserInfo(datos)
        print("[Gestor] Result queued for transfer")
    }
    
    // MARK: - Data Processing
    
    private func procesarDatos(_ diccionario: [String: Any]) {
        DispatchQueue.main.async {
            // Case A: Payload contains Match List (Watch target)
            if let data = diccionario["partidos"] as? Data {
                do {
                    let partidos = try JSONDecoder().decode([PartidoReloj].self, from: data)
                    self.partidosRecibidos = partidos
                    print("[Gestor] Match list updated")
                    
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.success)
                    #endif
                } catch {
                    print("[Gestor] Decode error: \(error)")
                }
            }
            
            // Case B: Payload contains Match Result (iOS target)
            if let idString = diccionario["idPartido"] as? String {
                print("[Gestor] Result received for ID: \(idString)")
                
                NotificationCenter.default.post(
                    name: .resultadoPartidoRecibido,
                    object: nil,
                    userInfo: diccionario
                )
            }
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("[Gestor] Session State: \(activationState.rawValue)")
        
        #if os(watchOS)
        DispatchQueue.main.async {
            if !session.receivedApplicationContext.isEmpty {
                self.procesarDatos(session.receivedApplicationContext)
            }
        }
        #endif
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        procesarDatos(applicationContext)
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        procesarDatos(userInfo)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        procesarDatos(message)
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif
}

// MARK: - Extensions

extension Notification.Name {
    static let resultadoPartidoRecibido = Notification.Name("resultadoPartidoRecibido")
}
