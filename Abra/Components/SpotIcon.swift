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
    
    var lightColor: Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: h, saturation: max(0, s - 0.15), brightness: min(1, b + 0.3), opacity: a)
    }

    private var iconForeground: LinearGradient {
        switch renderingMode {
        case .plain:
            return LinearGradient(colors: [.white], startPoint: .top, endPoint: .bottom)
        case .hierarchical, .iconOnly:
            return LinearGradient(colors: [lightColor, color], startPoint: .top, endPoint: .bottom)
        }
    }

    private var iconBackground: LinearGradient {
        switch renderingMode {
        case .iconOnly:
            return LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom)
        case .hierarchical:
            return LinearGradient(colors: [color.opacity(0.15)], startPoint: .top, endPoint: .bottom)
        case .plain:
            let colors: [Color] = symbol.isEmpty ? [.gray.opacity(0.2)] : [lightColor, color, color]
            return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottomTrailing)
        }
    }

    var body: some View {
        Image(systemName: symbol == "" ? "plus.circle.fill" : symbol)
            .resizable()
            .scaledToFit()
            .frame(width: size / 2, height: size / 2)
            .foregroundStyle(iconForeground)
            .frame(width: size, height: size)
            .background(iconBackground)
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
