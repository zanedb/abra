//
//  SearchBar.swift
//  Abra
//

import SwiftUI

struct SearchBar: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var prompt: String = "Search…"
    @Binding var search: String
    @FocusState var focused: Bool
    @EnvironmentObject private var vm: ViewModel
    
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
                        .font(.system(size: 17))
                }
                    .padding(.leading, 3)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeInOut(duration: 0.2)),
                        removal: .opacity.animation(.easeInOut(duration: 0.01))
                    ))
            } else {
                Button(action: { Task { await vm.match() } }) {
                    Image(systemName: "shazam.logo.fill")
                        .symbolRenderingMode(.multicolor)
                        .tint(.blue)
                        .fontWeight(.medium)
                        .font(.system(size: 36))
                        .cornerRadius(100)
                }
                    .padding(.leading, -3)
            }
        }
            .padding(.top, focused ? 3.2 : 0)
    }
}

#Preview {
    NavigationStack {
        SearchBar(search: .constant(""), focused: FocusState())
            .padding()
            .environmentObject(ViewModel())
        List {
            
        }
        .listStyle(.plain)
        .searchable(text: .constant(""), placement: .toolbar, prompt: "Search Shazams…")
    }
}
