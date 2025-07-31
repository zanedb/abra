//
//  SpotRow.swift
//  Abra
//

import SwiftUI

struct SpotRow: View {
    var spot: Spot

    var body: some View {
        HStack {
            SpotIcon(symbol: spot.symbol, color: Color(spot.color), size: 48, renderingMode: .hierarchical)
                .padding(.trailing, 5)

            VStack(alignment: .leading) {
                Text(spot.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(spot.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(alignment: .leading) {
        SpotRow(spot: .preview)
    }
}
