import SwiftUI

struct ContentView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView(appState: appState)

            ZStack(alignment: .top) {
                SimulationCanvas(appState: appState)

                if appState.showAccelBanner {
                    AccelBanner(onDismiss: { appState.showAccelBanner = false })
                        .padding(.top, 4)
                }
            }
        }
        .background(Color(red: 0x1A / 255.0, green: 0x1A / 255.0, blue: 0x1A / 255.0))
        .onKeyPress(.space) {
            appState.isPaused.toggle()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "d")) { _ in
            appState.drainMode.toggle()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "[")) { _ in
            appState.brushRadius = max(1, appState.brushRadius - 1)
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "]")) { _ in
            appState.brushRadius = min(20, appState.brushRadius + 1)
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "1234567890-=")) { press in
            selectElement(from: press.characters)
            return .handled
        }
        // Cmd+Backspace handled via menu commands in App.swift
    }

    private func selectElement(from chars: String) {
        guard let char = chars.first else { return }
        let elements = ElementType.drawable
        let index: Int?
        switch char {
        case "1": index = 0
        case "2": index = 1
        case "3": index = 2
        case "4": index = 3
        case "5": index = 4
        case "6": index = 5
        case "7": index = 6
        case "8": index = 7
        case "9": index = 8
        case "0": index = 9
        case "-": index = 10
        case "=": index = 11
        default: index = nil
        }
        if let i = index, i < elements.count {
            appState.selectedElement = elements[i]
        }
    }
}

struct AccelBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Text("Accelerometer unavailable — running in static gravity mode.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Button(action: onDismiss) {
                Text("\u{2715}")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.3))
        .cornerRadius(6)
        .padding(.horizontal, 12)
    }
}
