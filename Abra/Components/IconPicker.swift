//
//  IconPicker.swift
//  Abra
//

import Foundation
import SwiftUI

struct IconPicker: View {
    @Environment(\.dismiss) private var dismiss
    
    private var symbols: [String] = ["bag", "house", "lightbulb", "lamp.desk"]
    
    private func fetchSymbols() -> [String] {
        guard let path = Bundle.main.path(forResource: "sfsymbols", ofType: "txt"),
              let content = try? String(contentsOfFile: path, encoding: .utf8)
        else {
            #if DEBUG
            assertionFailure("[SymbolPicker] Failed to load bundle resource file.")
            #endif
            return []
        }
        return content
            .split(separator: "\n")
            .map { String($0) }
    }
    
    @Binding public var symbol: String
    @State private var searchText = ""
    
    public init(symbol: Binding<String>) {
        _symbol = symbol
        
        symbols = fetchSymbols()
    }

    var body: some View {
        NavigationStack {
            symbolGrid
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
                .navigationTitle("Choose Icon")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var symbolGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64, maximum: 64))]) {
                ForEach(symbols.filter { searchText.isEmpty ? true : $0.localizedCaseInsensitiveContains(searchText) }, id: \.self) { thisSymbol in
                    Button {
                        symbol = thisSymbol
                        dismiss()
                    } label: {
                        icon(thisSymbol, selected: thisSymbol == symbol)
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.lift)
                }
            }
            
            if (symbols.filter { searchText.isEmpty ? true : $0.localizedCaseInsensitiveContains(searchText) }.isEmpty) {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }
    
    private func icon(_ name: String, selected: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 24))
            .frame(maxWidth: .infinity, minHeight: 64)
            .cornerRadius(8)
    }
}

struct IconPicker_Previews: PreviewProvider {
    static var previews: some View {
        IconPicker(symbol: .constant(""))
    }
}
