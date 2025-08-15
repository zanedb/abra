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
            .foregroundStyle(renderingMode == .iconOnly || renderingMode == .hierarchical ? color : .white)
            .frame(width: size, height: size)
            .background(
                renderingMode == .iconOnly
                    ? .clear
                    : (symbol == "" ? .gray.opacity(0.20) : (renderingMode == .hierarchical ? color.opacity(0.15) : color))
            )
            .clipShape(Circle())
    }
}

#Preview {
    HStack {
        SpotIcon(symbol: "plus.circle.fill", color: .red, size: 144, renderingMode: .iconOnly)
        SpotIcon(symbol: "bicycle", color: .red, size: 80, renderingMode: .hierarchical)
        SpotIcon(symbol: "play", color: .red)
    }
}
