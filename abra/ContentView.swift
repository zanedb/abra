//
//  ContentView.swift
//  abra
//
//  Created by Zane on 6/5/23.
//

import SwiftUI

struct ContentView: View {
     @EnvironmentObject private var vm: ViewModel
    
    var body: some View {
        ZStack(alignment: .top) {
            UIKitMapView()
                .edgesIgnoringSafeArea(.all)
                .sheet(isPresented: .constant(true)) {
                    sheet
                }
            
            HStack(alignment: .top) {
                Spacer()
                LocateButton()
            }
                .padding(.trailing, 10)
        }
    }
    
    private var sheet: some View {
        SheetView()
            .padding(.top, 4)
            .environment(\.selectedDetent, vm.selectedDetent)
            .readHeight() // track view height for map
            .onPreferenceChange(HeightPreferenceKey.self) { height in
                if let height {
                    vm.detentHeight = height
                }
            }
            .presentationDetents([.height(65), .fraction(0.50), .large], largestUndimmed: .large, selection: $vm.selectedDetent)
            .interactiveDismissDisabled()
            .ignoresSafeArea()
            .sheet(isPresented: $vm.shazam.searching) {
                searching
            }
            .sheet(isPresented: $vm.newPlaceSheetShown) {
                newPlace
            }
    }
    
    private var searching: some View {
        Searching()
            .presentationDetents([.fraction(0.50)]/*, largestUndimmed: .large*/)
            .interactiveDismissDisabled()
            .presentationDragIndicator(.hidden)
            .overlay(
                Button { vm.shazam.stopRecognition() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 36))
                        .symbolRenderingMode(.hierarchical)
                        .padding(.vertical)
                        .padding(.trailing, -5)
                },
                alignment: .topTrailing
            )
    }
    
    private var newPlace: some View {
        NewPlace()
            .presentationDetents([.large])
            .interactiveDismissDisabled()
            .presentationDragIndicator(.hidden)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
        
//        ContentView()
//            .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
//            .previewDisplayName("iPad Pro 12.9")
    }
}
