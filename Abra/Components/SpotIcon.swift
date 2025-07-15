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
            .font(.system(size: symbol == "" ? 24 : 28)) // 12 on minimized
            .frame(width: size, height: size)
            .foregroundColor(.white)
            .background(symbol == "" ? .gray.opacity(0.20) : color)
            .clipShape(Circle())
            .padding(.trailing, 5)
    }
}

#Preview {
    HStack {
        SpotIcon(symbol: "plus.circle.fill", color: .red)
        SpotIcon(symbol: "plus.circle.fill", color: .red)
    }
}
