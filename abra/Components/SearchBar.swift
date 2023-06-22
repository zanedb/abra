//
//  SearchBar.swift
//  abra
//
//  Created by Zane on 6/18/23.
//

import SwiftUI
import Combine

struct SearchBar: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var prompt: String = "Search…"
    @Binding var search: String
    @FocusState var focused: Bool
    @ObservedObject var shazam: Shazam
    
    var body: some View {
        HStack(alignment: .center) {
            TextField(prompt, text: $search, prompt:
                Text(prompt)
                    .foregroundColor(.gray)
            )
                .padding(7)
                .padding(.leading, 24)
                .background(.gray.opacity(colorScheme == .light ? 0.13 : 0.20))
                .cornerRadius(9)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 7)
                        if (search != "") {
                            Button(action: {
                                self.search = ""
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 6)
                            }
                        }
                    }
                )
                .focused($focused)
            
            if (focused || (!focused && search != "")) {
                Button(action: {
                    focused = false
                    self.search = ""
                }) {
                    Text("Cancel")
                        .font(.system(size:18))
                }
                    .padding(.leading, 3)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeInOut(duration: 0.2)),
                        removal: .opacity.animation(.easeInOut(duration: 0.1))
                    ))
            } else {
                ShazamButton(
                    searching: shazam.searching,
                    start: { shazam.startRecognition() },
                    stop: { shazam.stopRecognition() },
                    size: 36
                )
                    .padding(.leading, -3)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeInOut(duration: 0.15)),
                        removal: .opacity.animation(.easeInOut(duration: 0.001))
                    ))
            }
        }
            .padding(.top, focused ? 3.2 : 0)
    }
}

struct SearchBar_Previews: PreviewProvider {
    @State private var search: String = ""
    
    static var previews: some View {
        NavigationStack {
            SearchBar(search: .constant(""), focused: FocusState(), shazam: Shazam())
                .padding()
            List {
                
            }
            .listStyle(.plain)
            .searchable(text: .constant(""), placement: .toolbar, prompt: "Search Shazams…")
        }
    }
}
