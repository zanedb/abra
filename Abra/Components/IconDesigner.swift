//
//  IconDesigner.swift
//  Abra
//

import Foundation
import SwiftData
import SwiftUI

struct IconCollection: Codable, Identifiable {
    let id: Int
    let title: String
    let contents: [String]
}

struct IconDesigner: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding public var symbol: String
    @Binding public var color: UIColor
    
    var animation: Namespace.ID
    var id: PersistentIdentifier
    
    @State private var searchText = ""
    
    private var collections: [IconCollection] = []
    private var systemColorOptions: [UIColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemMint, .systemCyan, .systemBlue, .systemIndigo, .systemPurple, .systemBrown, .systemGray]
    
    private func fetchSymbols() -> [IconCollection] {
        guard let path = Bundle.main.path(forResource: "sfsymbols", ofType: "json"),
              let collections = try? JSONDecoder().decode([IconCollection].self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        else {
            #if DEBUG
            assertionFailure("[IconDesigner] Failed to load bundle resource file.")
            #endif
            return []
        }
        return collections
    }
    
    public init(symbol: Binding<String>, color: Binding<UIColor>, animation: Namespace.ID, id: PersistentIdentifier) {
        _symbol = symbol
        _color = color
        self.animation = animation
        self.id = id
        
        collections = fetchSymbols()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Wrapper {
                    SpotIcon(symbol: symbol, color: Color(color), size: 96)
                        .navigationTransition(.zoom(sourceID: id, in: animation))
                }
                    
                Wrapper {
                    colorGrid
                }
                    
                Wrapper {
                    if searchText.isEmpty {
                        symbolGrid
                    } else {
                        searchResults
                    }
                }
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal)
            .navigationTitle("Icon")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Symbols")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    DismissButton()
                }
            }
        }
    }
    
    private var colorGrid: some View {
        let colorBinding = Binding(
            get: { Color(self.color) },
            set: { self.color = UIColor($0) }
        )
        
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 48, maximum: 64))]) {
            ForEach(systemColorOptions, id: \.self) { color in
                Circle()
                    .fill(Color(color))
                    .frame(width: 48, height: 48)
                    .onTapGesture {
                        withAnimation { self.color = color }
                    }
                    .overlay {
                        if self.color == color {
                            Image(systemName: "checkmark")
                                .font(.system(size: 21, weight: .bold))
                                .foregroundStyle(.background)
                        }
                    }
            }
            
            ColorPicker("Icon Color", selection: colorBinding)
                .labelsHidden()
                .scaleEffect(1.8)
        }
    }
    
    private var symbolGrid: some View {
        VStack(alignment: .leading) {
            ForEach(collections) { collection in
                Text(collection.title)
                    .font(.subheading)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 48, maximum: 64))]) {
                    ForEach(collection.contents, id: \.self) { thisSymbol in
                        iconButton(thisSymbol)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
    
    private var searchResults: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 48, maximum: 64))]) {
            ForEach(Array(Set(collections.flatMap(\.contents))).filter { $0.localizedCaseInsensitiveContains(searchText) }, id: \.self) { thisSymbol in
                iconButton(thisSymbol)
            }
        }
    }
    
    private func iconButton(_ thisSymbol: String) -> some View {
        Button {
            symbol = thisSymbol
        } label: {
            Image(systemName: thisSymbol)
                .font(.system(size: 24))
                .frame(width: 48, height: 48)
                .background(thisSymbol == symbol ? Color.secondary.opacity(0.2) : Color.clear)
                .foregroundStyle(thisSymbol == symbol ? .secondary : .secondary)
                .clipShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var symbol = ""
    @Previewable @State var color = UIColor.systemIndigo
    @Previewable @Namespace var animation
    
    VStack {}
        .popover(isPresented: .constant(true)) {
            IconDesigner(symbol: $symbol, color: $color, animation: animation, id: Spot.preview.id)
                .presentationDetents([.fraction(0.999)])
                .presentationBackground(.thickMaterial)
                .presentationCornerRadius(14)
        }
}
