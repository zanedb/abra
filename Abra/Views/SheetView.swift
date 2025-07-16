//
//  SheetView.swift
//  Abra
//

import SectionedQuery
import ShazamKit
import SwiftData
import SwiftUI

struct SheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastProvider) private var toast
    @Environment(\.openURL) private var openURL
    @Environment(SheetProvider.self) private var view
    @Environment(ShazamProvider.self) private var shazam
    @Environment(LocationProvider.self) private var location
    
    @Binding var searchText: String
    
    var filtered: [ShazamStream]
    
    @SectionedQuery(\.timeGroupedString, sort: [SortDescriptor(\.timestamp, order: .reverse)]) private var timeSections: SectionedResults<String, ShazamStream>
    
    @State private var minimizedOpacity: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                SearchBar(text: $searchText, placeholder: "Search Shazams")
                    
                Button(action: { Task { await shazam.startMatching() } }) {
                    Image(systemName: "shazam.logo.fill")
                        .symbolRenderingMode(.multicolor)
                        .tint(.blue)
                        .fontWeight(.medium)
                        .font(.system(size: 36))
                }
            }
            .padding(.trailing)
            .padding(.leading, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            Divider()
                .opacity(minimizedOpacity)
            
            List {
                if searchText.isEmpty && filtered.isEmpty {
                    ContentUnavailableView {} description: { Text("Your library is empty.") }
                        .padding()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else if searchText.isEmpty {
                    SpotsList()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.top, 8)
                    
                    ForEach(timeSections) { section in
                        Section(header: Text("\(section.id)")) {
                            ForEach(section, id: \.self) { shazam in
                                Button(action: { view.show(shazam) }) {
                                    SongRow(stream: shazam)
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listSectionSeparator(.hidden, edges: .bottom)
                    }
                } else if !searchText.isEmpty && filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(filtered, id: \.id) { shazam in
                        Button(action: { view.show(shazam) }) {
                            SongRow(stream: shazam)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .opacity(minimizedOpacity)
            .overlay(alignment: .top) {
                VariableBlurView(maxBlurRadius: 1, direction: .blurredTopClearBottom)
                    .frame(height: 4)
            }
        }
        .onChange(of: shazam.status) {
            if case .matched(let song) = shazam.status {
                createShazamStream(song)
            }
            
            if case .error(let error) = shazam.status {
                handleShazamAPIError(error)
            }
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { minimizedOpacity = ($0.height > 100) ? 1 : 0 }
    }
    
    private func createShazamStream(_ mediaItem: SHMediaItem) {
        // Handle lack of available location
        guard location.currentLocation != nil else {
            toast.show(
                message: "Location unavailable",
                type: .error,
                symbol: "location.slash.fill",
                action: {
                    // On permissions issue, tapping takes you right to app settings!
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                }
            )
            return
        }
        
        // Create and show ShazamStream
        let stream = ShazamStream(mediaItem: mediaItem, location: location.currentLocation!, placemark: location.currentPlacemark, modelContext: modelContext)
        modelContext.insert(stream)
        view.show(stream)
    }
    
    private func handleShazamAPIError(_ error: ShazamError) {
        switch error {
        case .noMatch:
            toast.show(message: "No match found", type: .info, symbol: "shazam.logo.fill")
        case .matchFailed(let error):
            toast.show(message: "Shazam error \(extractShazamErrorCode(from: error.localizedDescription))", type: .error, symbol: "shazam.logo.fill")
            Task { await shazam.startMatching() } // retry
        default:
            break
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
