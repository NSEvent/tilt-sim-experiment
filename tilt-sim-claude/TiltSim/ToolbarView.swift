import SwiftUI

struct ToolbarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            // Element buttons
            ForEach(ElementType.drawable, id: \.rawValue) { element in
                ElementButton(
                    element: element,
                    isSelected: appState.selectedElement == element,
                    action: { appState.selectedElement = element }
                )
            }

            Spacer()

            // Clear button
            Button(action: { appState.clearGrid() }) {
                Text("Clear")
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Drain toggle
            Button(action: { appState.drainMode.toggle() }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(appState.drainMode ? Color.green : Color.gray.opacity(0.4))
                        .frame(width: 8, height: 8)
                    Text("Drain")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Pause/Play
            Button(action: { appState.isPaused.toggle() }) {
                Text(appState.isPaused ? "\u{25B6}" : "\u{23F8}")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(Color(nsColor: NSColor(red: 0x1A / 255.0, green: 0x1A / 255.0, blue: 0x1A / 255.0, alpha: 1)))
    }
}

struct ElementButton: View {
    let element: ElementType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(
                        red: Double(element.baseColor.r) / 255.0,
                        green: Double(element.baseColor.g) / 255.0,
                        blue: Double(element.baseColor.b) / 255.0
                    ))
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                    )
                Text(element.name)
                    .font(.system(size: 9))
                    .foregroundColor(Color(white: 0.8))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}
