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
    
    @Binding var detent: PresentationDetent
    @Binding var selection: ShazamStream?
    @Binding var searchText: String
    
    @State var viewBy: ViewBy = .time
    
    var filtered: [ShazamStream]
    
    @SectionedQuery(\.timeGroupedString, sort: [SortDescriptor(\.timestamp, order: .reverse)]) private var timeSections: SectionedResults<String, ShazamStream>
    
    @SectionedQuery(\.placeGroupedString, sort: [SortDescriptor(\.timestamp, order: .reverse)]) private var placeSections: SectionedResults<String, ShazamStream>
    
    var body: some View {
        VStack {
            SearchBar(prompt: "Search Shazams", search: $searchText)
                .padding(.horizontal)
                .padding(.top, detent != PresentationDetent.height(65) ? 14 : 0)
            
            if detent != PresentationDetent.height(65) {
                VStack(spacing: 0) {
                    if searchText.isEmpty && filtered.isEmpty {
                        ContentUnavailableView {} description: { Text("Your library is empty.") }
                    } else if searchText.isEmpty {
                        PlacesList(places: [Place.preview])
//                        picker
                        
                        List {
                            ForEach(viewBy == .time ? timeSections : placeSections) { section in
                                Section {
                                    ForEach(section, id: \.self) { shazam in
                                        Button(action: { selection = shazam }) {
                                            SongRow(stream: shazam)
                                        }
                                        .listRowBackground(Color.clear)
                                    }
                                } header: {
                                    HStack {
                                        Text("\(section.id)")
                                        if viewBy == .place {
                                            Spacer()
                                            Button(action: {}) {
                                                Label("New Place", systemImage: "plus")
                                            }
                                        }
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
                                Button(action: { selection = shazam }) {
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
}
