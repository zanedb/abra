//
//  SearchBar.swift
//  Abra
//

import SwiftUI

struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    
    func makeUIView(context: UIViewRepresentableContext<SearchBar>) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = placeholder
        searchBar.autocapitalizationType = .none
        return searchBar
    }
    
    func updateUIView(_ uiView: UISearchBar, context: UIViewRepresentableContext<SearchBar>) {
        uiView.text = text
    }
    
    func makeCoordinator() -> SearchBar.Coordinator {
        return Coordinator(text: $text)
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    class Coordinator: NSObject, UISearchBarDelegate {
        private var textBinding: Binding<String>
                
        init(text: Binding<String>) {
            self.textBinding = text
            super.init()
        }
                
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            textBinding.wrappedValue = searchText
        }
    }
}
