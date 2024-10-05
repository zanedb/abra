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
    
    @Binding var searchText: String
    @Binding var viewBy: ViewBy
    var filtered: [ShazamStream]
    var sections: SectionedResults<String, ShazamStream>
    
    var body: some View {
        VStack {
            SearchBar(prompt: "Search Shazams", search: $searchText)
                .padding(.horizontal)
                .padding(.top, vm.selectedDetent != PresentationDetent.height(65) ? 14 : 0)
            
            if (vm.selectedDetent != PresentationDetent.height(65)) {
                VStack(spacing: 0){
                    if(searchText.isEmpty && filtered.isEmpty) {
                        EmptyLibrary()
                    } else if (searchText.isEmpty) {
                        picker
                        
                        List {
                            ForEach(sections) { section in
                                Section(header: Text("\(section.id)")) {
                                    ForEach(section, id: \.self) { shazam in
                                        Button(action: { vm.selectedSS = shazam }) {
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
                                Button(action: { vm.selectedSS = shazam }) {
                                    SongRow(stream: shazam)
                                }
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
            // Map annotation tapped -> set selection on ViewModel
            .onChange(of: vm.mapSelection) {
                if let sstream = modelContext.model(for: vm.mapSelection!) as? ShazamStream {
                    vm.selectedSS = sstream
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
