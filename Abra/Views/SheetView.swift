//
//  SheetView.swift
//  Abra
//

import SectionedQuery
import SwiftData
import SwiftUI

enum ViewBy {
    case time
    case place
}

struct SheetView: View {
    @EnvironmentObject private var vm: ViewModel
    
    @Binding var searchText: String
    @Binding var viewBy: ViewBy
    var filtered: [ShazamStream]
    var sections: SectionedResults<String, ShazamStream>
    
    var body: some View {
        VStack {
            SearchBar(prompt: "Search Shazams", search: $searchText)
                .padding(.horizontal)
                .padding(.top, vm.selectedDetent != PresentationDetent.height(65) ? 14 : 0)
            
            if vm.selectedDetent != PresentationDetent.height(65) {
                VStack(spacing: 0) {
                    if searchText.isEmpty && filtered.isEmpty {
                        ContentUnavailableView {} description: { Text("Your library is empty.") }
                    } else if searchText.isEmpty {
                        picker
                        
                        List {
                            ForEach(sections) { section in
                                Section(header: Text("\(section.id)")) {
                                    ForEach(section, id: \.self) { shazam in
                                        Button(action: { vm.selectedSS = shazam }) {
                                            SongRow(stream: shazam)
                                        }
                                        .listRowBackground(Color.clear)
                                    }
                                }
                                .listSectionSeparator(.hidden, edges: .bottom)
                            }
                        }
                        .listStyle(.inset)
                        .scrollContentBackground(.hidden)
                    } else if !searchText.isEmpty && filtered.isEmpty {
                        ContentUnavailableView {
                            Label("No Results", systemImage: "moon.stars")
                        } description: {
                            Text("Try a new search.")
                        }
                    } else {
                        List {
                            ForEach(filtered, id: \.id) { shazam in
                                Button(action: { vm.selectedSS = shazam }) {
                                    SongRow(stream: shazam)
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.inset)
                        .scrollContentBackground(.hidden)
                    }
                }
                .transition(.asymmetric(
                    insertion: .push(from: .bottom).animation(.easeInOut(duration: 0.25)),
                    removal: .opacity.animation(.easeInOut(duration: 0.15)))
                )
            }
        }
    }
    
    var picker: some View {
        Picker("", selection: $viewBy) {
            Text("Recents").tag(ViewBy.time)
            Text("Locations").tag(ViewBy.place)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
        .environmentObject(ViewModel())
        .environmentObject(LibraryService())
}
