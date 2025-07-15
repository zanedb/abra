//
//  SpotIcon.swift
//  Abra
//

import SwiftUI

struct SpotIcon: View {
    var symbol: String
    var color: Color
    var size: CGFloat = 40
    
    var body: some View {
        Image(systemName: symbol == "" ? "plus.circle.fill" : symbol)
            .resizable()
            .scaledToFit()
            .frame(width: size / 2, height: size / 2)
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(symbol == "" ? .gray.opacity(0.20) : color)
            .clipShape(Circle())
    }
}

#Preview {
    HStack {
        SpotIcon(symbol: "key.fill", color: .red, size: 144)
        SpotIcon(symbol: "plus.circle.fill", color: .red, size: 144)
        SpotIcon(symbol: "bicycle", color: .red, size: 80)
        SpotIcon(symbol: "play", color: .red)
    }
}
