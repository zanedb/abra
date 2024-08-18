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

// navPath.append() requires type to be Codable
// therefore I must wrap ShazamStream's id in an otherwise useless struct
struct Path: Hashable, Codable {
    var sStreamId: PersistentIdentifier?
}

struct SheetView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var vm: ViewModel
    
    @State var navPath = NavigationPath()
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
                // Find ShazamStream from id and display SongView
                .navigationDestination(for: Path.self) { selection in
                    if let sstream = modelContext.model(for: selection.sStreamId!) as? ShazamStream {
                        SongView(stream: sstream)
                    }
                }
                .navigationTitle("Library")
                .navigationBarTitleDisplayMode(.inline)
        }
        // Map annotation tapped -> wrap id in Path and add to navPath
        .onChange(of: vm.mapSelection) {
            navPath.append(Path(sStreamId: vm.mapSelection!))
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
        .environmentObject(ViewModel())
}
