//
//  SheetView.swift
//  abra
//
//  Created by Zane on 6/17/23.
//

import SwiftUI
import SwiftData
import SectionedQuery

enum ViewBy {
    case time
    case place
}

struct SheetView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var vm: ViewModel
    
    @FocusState var focused: Bool
    @Binding var searchText: String
    @Binding var viewBy: ViewBy
    var filtered: [ShazamStream]
    var sections: SectionedResults<String, ShazamStream>
    
    var body: some View {
        NavigationStack(path: $navPath) {
            VStack {
                SearchBar(prompt: "Search Shazams", search: $searchText, focused: _focused)
                    .padding(.horizontal)
                    .padding(.top, (vm.selectedDetent != PresentationDetent.height(65) || focused) ? 14 : 0)
                    .onChange(of: focused) {
                        // MARK: this doesn't work.
                        // TODO: fix.
                        print(focused)
                    }
                
                if (vm.selectedDetent != PresentationDetent.height(65) || focused) {
                    VStack(spacing: 0){
                        if(searchText.isEmpty && filtered.isEmpty) {
                            EmptyLibrary()
                        } else if (searchText.isEmpty) {
                            Picker("", selection: $viewBy) {
                                Text("Recents").tag(ViewBy.time)
                                Text("Locations").tag(ViewBy.place)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                            List {
                                ForEach(sections) { section in
                                    Section(header: Text("\(section.id)")) {
                                        ForEach(section, id: \.self) { shazam in
                                            NavigationLink {
                                                SongView(stream: shazam)
                                            } label: {
                                                SongRow(stream: shazam)
                                            }
                                        }
                                    }
                                    .listSectionSeparator(.hidden, edges: .bottom)
                                }
                            }
                            .listStyle(.inset)
                        } else if (!searchText.isEmpty && filtered.isEmpty) {
                            NoResults()
                        } else {
                            List {
                                ForEach(filtered, id: \.id) { shazam in
                                    SongRow(stream: shazam)
                                }
                            }
                            .listStyle(.inset)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .push(from: .bottom).animation(.easeInOut(duration: 0.25)),
                        removal: .opacity.animation(.easeInOut(duration: 0.15)))
                    )
                }
            }
                .toolbar(.hidden)
                .navigationTitle("Library")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
        .environmentObject(ViewModel())
}
