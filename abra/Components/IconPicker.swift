//
//  IconPicker.swift
//  abra
//
//  Created by Zane on 7/14/23.
//

import Foundation
import SwiftUI

struct IconPicker: View {
    private var symbols: [String] = ["bag", "house", "lightbulb", "lamp.desk"]
    
    private func fetchSymbols() -> [String] {
        guard let path = Bundle.main.path(forResource: "sfsymbols", ofType: "txt"),
              let content = try? String(contentsOfFile: path) else {
            #if DEBUG
            assertionFailure("[SymbolPicker] Failed to load bundle resource file.")
            #endif
            return []
        }
        return content
            .split(separator: "\n")
            .map { String($0) }
    }

    private static var gridDimension: CGFloat {
        #if os(iOS)
        return 64
        #elseif os(tvOS)
        return 128
        #elseif os(macOS)
        return 48
        #else
        return 48
        #endif
    }

    private static var symbolSize: CGFloat {
        #if os(iOS)
        return 24
        #elseif os(tvOS)
        return 48
        #elseif os(macOS)
        return 24
        #else
        return 24
        #endif
    }

    private static var symbolCornerRadius: CGFloat {
        #if os(iOS)
        return 8
        #elseif os(tvOS)
        return 12
        #elseif os(macOS)
        return 8
        #else
        return 8
        #endif
    }
    
    // TODO: write background color picker
    private static var selectedItemBackgroundColor: Color {
        return Color.accentColor
    }
    
    private static var unselectedItemBackgroundColor: Color {
        #if os(iOS)
        return Color(UIColor.systemBackground)
        #else
        return .clear
        #endif
    }
    
    @Binding public var symbol: String
    @State private var searchText = ""
    
    @Environment(\.presentationMode) private var presentationMode
    
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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.gridDimension, maximum: Self.gridDimension))]) {
                ForEach(symbols.filter { searchText.isEmpty ? true : $0.localizedCaseInsensitiveContains(searchText) }, id: \.self) { thisSymbol in
                    Button {//[penis]
                        symbol = thisSymbol
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        if thisSymbol == symbol {
                            Image(systemName: thisSymbol)
                                .font(.system(size: Self.symbolSize))
                                #if os(tvOS)
                                .frame(minWidth: Self.gridDimension, minHeight: Self.gridDimension)
                                #else
                                .frame(maxWidth: .infinity, minHeight: Self.gridDimension)
                                #endif
                                .background(Self.selectedItemBackgroundColor)
                                .cornerRadius(Self.symbolCornerRadius)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: thisSymbol)
                                .font(.system(size: Self.symbolSize))
                                .frame(maxWidth: .infinity, minHeight: Self.gridDimension)
                                .background(Self.unselectedItemBackgroundColor)
                                .cornerRadius(Self.symbolCornerRadius)
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.lift)
                }
            }
            
            if (symbols.filter { searchText.isEmpty ? true : $0.localizedCaseInsensitiveContains(searchText) }.isEmpty) {
                NoResults()
            }
        }
    }
}

struct IconPicker_Previews: PreviewProvider {
    static var previews: some View {
        IconPicker(symbol: .constant(""))
    }
}
