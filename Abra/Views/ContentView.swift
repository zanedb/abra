//
//  ContentView.swift
//  Abra
//

import MapKit
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var vm: ViewModel
    
    @AppStorage("hasCompletedOnboarding") var onboarded: Bool = false
    
    @State var detent: PresentationDetent = .medium
    @State var selection: ShazamStream? = nil
    @State var groupSelection: ShazamStreamGroup? = nil
    @State var searchText: String = ""
    
    @Query(sort: \ShazamStream.timestamp, order: .reverse)
    var shazams: [ShazamStream]
    
    var filtered: [ShazamStream] {
        guard searchText.isEmpty == false else { return shazams }
        
        return shazams.filter { $0.title.lowercased().contains(searchText.lowercased()) }
    }
    
    var body: some View {
            .inspector(isPresented: .constant(true)) {
                SheetView(searchText: $searchText, viewBy: $viewBy, filtered: filtered, sections: viewBy == .time ? timeSections : placeSections)
                    .presentationDetents([.height(65), .fraction(0.50), .large], selection: $vm.selectedDetent)
                    .presentationBackgroundInteraction(.enabled)
                    .interactiveDismissDisabled()
        MapView(detent: $detent, sheetSelection: $selection, groupSelection: $groupSelection, shazams: filtered)
                    .sheet(isPresented: $vm.isMatching) {
                        searching
                    }
                    .sheet(item: $vm.selectedSS) { selection in
                        SongView(stream: selection)
                            .presentationDetents([.fraction(0.50), .large])
                            .presentationBackgroundInteraction(.enabled)
                            .edgesIgnoringSafeArea(.bottom)
                    }
//                        .sheet(isPresented: $vm.newPlaceSheetShown) {
//                            newPlace
//                        }
            }
            .overlay {
                if !onboarded {
                    VisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                    
                    OnboardingView()
                        .transition(.blurReplace.animation(.easeInOut(duration: 0.25)))
                }
            }
            .overlay(alignment: .top) {
                GeometryReader { geom in
                    VariableBlurView(maxBlurRadius: 5, direction: .blurredTopClearBottom)
                        .frame(height: geom.safeAreaInsets.top)
                        .ignoresSafeArea()
                }
            }
            .onAppear {
                // MARK: Obtain modelContext in ViewModel through .onAppear modifier
                // There's probably a better solution.

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
    
//    private var newPlace: some View {
//        NewPlace()
//            .presentationDetents([.large])
//            .interactiveDismissDisabled()
//            .presentationDragIndicator(.hidden)
//    }
}

#Preview {
    ContentView()
        .environmentObject(ViewModel())
        .modelContainer(PreviewSampleData.container)
        .environmentObject(LibraryService())
}
