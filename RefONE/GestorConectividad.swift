import Foundation
import WatchConnectivity
import SwiftUI
import Combine

class GestorConectividad: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = GestorConectividad()
    
    // Variable para guardar la lista en el Reloj
    @Published var partidosRecibidos: [PartidoReloj] = [] {
        didSet {
            // Pequeña persistencia para que el reloj no pierda datos al apagarse
            if let data = try? JSONEncoder().encode(partidosRecibidos) {
                UserDefaults.standard.set(data, forKey: "partidos_cache")
            }
        }
    }
    
    override init() {
        super.init()
        // Cargar caché si existe (útil en el Watch al iniciar)
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
    
    // MARK: - ENVÍO (iPhone -> Watch)
    
    func enviarPartidosAlReloj(_ partidos: [PartidoReloj]) {
        if WCSession.default.activationState != .activated { WCSession.default.activate() }
        
        do {
            let data = try JSONEncoder().encode(partidos)
            let diccionario: [String: Any] = ["partidos": data]
            
            // 1. Contexto (Sobrescribe datos viejos, ideal para listas)
            try WCSession.default.updateApplicationContext(diccionario)
            
            // 2. Mensaje Directo (Intento inmediato si está la app abierta)
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(diccionario, replyHandler: nil)
            }
            print("📤 [Gestor] Lista de partidos enviada al reloj.")
        } catch {
            print("❌ [Gestor] Error enviando: \(error)")
        }
    }
    
    
    // MARK: - ENVÍO RESULTADO (Watch -> iPhone)
        
    func enviarResultadoAlIphone(idPartido: UUID, golesLocal: Int, golesVisitante: Int, workoutID: UUID?) {
        // Preparamos el paquete
        var datos: [String: Any] = [
            "tipo": "resultadoFinal", // Etiqueta para saber qué es
            "idPartido": idPartido.uuidString,
            "golesLocal": golesLocal,
            "golesVisitante": golesVisitante,
            "fechaFin": Date().timeIntervalSince1970
        ]
        
        if let wID = workoutID {
            datos["workoutID"] = wID.uuidString
        }
        
        // USAMOS transferUserInfo (Cola de mensajería robusta)
        WCSession.default.transferUserInfo(datos)
        
        print("⌚️ Resultado puesto en la cola de envío. Se entregará cuando conecte.")
    }
    
    private func procesarDatos(_ diccionario: [String: Any]) {
        DispatchQueue.main.async {
            
            // CASO A: Recibimos una LISTA de partidos (Esto pasa en el Watch)
            if let data = diccionario["partidos"] as? Data {
                do {
                    let partidos = try JSONDecoder().decode([PartidoReloj].self, from: data)
                    self.partidosRecibidos = partidos
                    print("✅ [Gestor] Lista de partidos actualizada.")
                    
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.success)
                    #endif
                } catch { print("Error decodificando lista: \(error)") }
            }
            
            // CASO B: Recibimos un RESULTADO FINAL (Esto pasa en el iPhone)
            // ---> ESTA ES LA PARTE QUE FALTABA Y QUE HACE FUNCIONAR EL .onReceive <---
            if let idString = diccionario["idPartido"] as? String {
                print("🏆 Resultado recibido del reloj para el partido: \(idString)")
                
                // Lanzamos el aviso general para que la Vista (ListaPartidosView) lo capture y guarde
                NotificationCenter.default.post(
                    name: .resultadoPartidoRecibido,
                    object: nil,
                    userInfo: diccionario
                )
            }
        }
    }
    
    // MARK: - DELEGADO WCSESSION
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("⌚️ WCSession activa: \(activationState.rawValue)")
        
        // En el Watch, al activarse, miramos si había datos pendientes
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
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
    #endif
}

// IMPORTANTE: La extensión para que el nombre de la notificación exista
extension Notification.Name {
    static let resultadoPartidoRecibido = Notification.Name("resultadoPartidoRecibido")
}
