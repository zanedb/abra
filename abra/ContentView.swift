//
//  ContentView.swift
//  abra
//
//  Created by Zane on 6/5/23.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @EnvironmentObject private var vm: NewViewModel
    
    var body: some View {
        ZStack(alignment: .top) {
            MapView()
                .inspector(isPresented: .constant(true)) {
                    NewSheetView()
                        .presentationDetents([.height(65), .fraction(0.50), .large], selection: $vm.selectedDetent)
                        .presentationBackgroundInteraction(.enabled)
                        .interactiveDismissDisabled()
                        .sheet(isPresented: $vm.isMatching) {
                            searching
                        }
//                        .sheet(isPresented: $vm.newPlaceSheetShown) {
//                            newPlace
//                        }
                }
        }
        .onAppear {
            // MARK: get modelContext in viewModel. prob not best solution.
            vm.modelContext = modelContext
        }
    }
    
    private var searching: some View {
        Searching()
            .presentationDetents([.fraction(0.50)])
            .interactiveDismissDisabled()
            .presentationDragIndicator(.hidden)
            .overlay(
                Button { vm.stopRecording() } label: {
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

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
        .environmentObject(NewViewModel())
    // .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
    // .previewDisplayName("iPad Pro 12.9")
}
