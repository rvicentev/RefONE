import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("RefONE")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.orange)
                
                NavigationLink(destination: ListaPartidosWatchView()) {
                    HStack {
                        Image(systemName: "whistle")
                        Text("Partidos")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
    }
}
