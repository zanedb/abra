//
//  SheetView.swift
//  abra
//
//  Created by Zane on 6/17/23.
//

import SwiftUI

struct SheetView: View {
    @Environment(\.selectedDetent) private var selectedDetent
    
    @EnvironmentObject private var vm: ViewModel
    @FocusState var focused: Bool
    
    var body: some View {
        NavigationStack {
            VStack {
                SearchBar(prompt: "Search Shazams…", search: $vm.searchText, focused: _focused)
                    .padding(.horizontal)
                    .padding(.top, (selectedDetent != PresentationDetent.height(65) || focused) ? 14 : 0)
                
                if (selectedDetent != PresentationDetent.height(65) || focused) { // TODO: animate this based on vm.detentHeight
                    VStack(spacing: 0) {
                        if (!vm.searchText.isEmpty && vm.streams.isEmpty) {
                            NoResults()
                        } else {
                            if (vm.searchText.isEmpty) { // MARK: temp remove places in search results bc they're useless!
                                PlacesList()
                                    .transition(.asymmetric(
                                        insertion: .push(from: .bottom).animation(.easeInOut(duration: 0.25)),
                                        removal: .opacity.animation(.easeInOut(duration: 0.15)))
                                    )
                            }
                            
                            HStack(spacing: 0) {
                                Text(vm.searchText.isEmpty ? "Recent Shazams" : "Search Results")
                                    .foregroundColor(.gray)
                                    .bold()
                                    .font(.system(size: 14))
                                    .id("Descriptor" + (vm.searchText.isEmpty ? "Library" : "Search"))
                                    .transition(.opacity.animation(.easeInOut(duration: 0.075)))
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 15)
                            
                            SongList()
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

struct SheetView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
