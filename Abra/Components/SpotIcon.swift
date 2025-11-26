//
//  SpotIcon.swift
//  Abra
//

import SwiftUI

struct SpotIcon: View {
    var symbol: String
    var color: Color
    var size: CGFloat = 40
    var renderingMode: RenderingMode = .plain

    enum RenderingMode {
        case plain
        case hierarchical
        case iconOnly
    }

    var body: some View {
        Image(systemName: symbol == "" ? "plus.circle.fill" : symbol)
            .resizable()
            .scaledToFit()
            .frame(width: size / 2, height: size / 2)
            .foregroundStyle(
                renderingMode == .iconOnly || renderingMode == .hierarchical
                    ? LinearGradient(
                        colors: [
                            color.opacity(0.7), color.opacity(1),
                            color.opacity(1),
                        ],
                        startPoint: .top,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [.white],
                        startPoint: .top,
                        endPoint: .bottom
                    )
            )
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: (renderingMode == .iconOnly
                        ? [.clear]
                        : (symbol.isEmpty
                            ? [.gray.opacity(0.2)]
                            : (renderingMode == .hierarchical
                                ? [color.opacity(0.15)]
                                : [
                                    color.opacity(0.7), color.opacity(1),
                                    color.opacity(1),
                                ]))),
                    startPoint: .top,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
    }
}

#Preview("SpotIcon") {
    HStack {
        SpotIcon(
            symbol: "plus.circle.fill",
            color: .red,
            size: 144
        )
        SpotIcon(
            symbol: "bicycle",
            color: .red,
            size: 80,
            renderingMode: .hierarchical
        )
        SpotIcon(symbol: "play", color: .red)
    }
}
