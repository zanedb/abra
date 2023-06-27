//
//  SheetView.swift
//  abra
//
//  Created by Zane on 6/17/23.
//

import SwiftUI

struct SheetView: View {
    @Environment(\.selectedDetent) private var selectedDetent
    
    @State var search: String = ""
    var streams: FetchedResults<SStream>
    
    @ObservedObject var shazam: Shazam
    @FocusState var focused: Bool
    
    var onSongTapped: (SStream) -> ()
    
    var body: some View {
        NavigationStack {
            VStack {
                SearchBar(prompt: "Search Shazams…", search: $search, focused: _focused, shazam: shazam)
                    .padding(.horizontal)
                    .padding(.top, (selectedDetent != PresentationDetent.height(65) || focused) ? 14 : 0)
                
                if (selectedDetent != PresentationDetent.height(65) || focused) {
                    VStack(spacing: 0) {
                        if (!search.isEmpty && streams.isEmpty) {
                            NoResults()
                        } else {
                            HStack(spacing: 0) {
                                Text(search.isEmpty ? "Recent Shazams" : "Search Results")
                                    .foregroundColor(.gray)
                                    .bold()
                                    .font(.system(size: 14))
                                    .id("Descriptor" + (search.isEmpty ? "Library" : "Search"))
                                    .transition(.opacity.animation(.easeInOut(duration: 0.075)))
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 15)
                            
                            SongList(streams: streams, onSongTapped: onSongTapped)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .push(from: .bottom).animation(.easeInOut(duration: 0.25)),
                        removal: .opacity.animation(.easeInOut(duration: 0.15)))
                    )
                }
            }
                .toolbar(.hidden)
                .onChange(of: search) { newValue in
                    streams.nsPredicate = newValue.isEmpty ? nil : NSPredicate(format: "trackTitle CONTAINS[c] %@", newValue)
                }
                .navigationTitle("Library")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SheetView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            //.environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
