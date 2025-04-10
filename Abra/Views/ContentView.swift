//
//  ContentView.swift
//  Abra
//

import MapKit
import SectionedQuery
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var vm: ViewModel
    
    @State var searchText: String = ""
    @State var viewBy: ViewBy = .time
    @State var position: MapCameraPosition = .automatic
    
    @Query(sort: \ShazamStream.timestamp, order: .reverse)
    var shazams: [ShazamStream]
    
    var filtered: [ShazamStream] {
        guard searchText.isEmpty == false else { return shazams }
        
        return shazams.filter { $0.title.lowercased().contains(searchText.lowercased()) }
    }
    
    @SectionedQuery(\.timeGroupedString, sort: [SortDescriptor(\.timestamp, order: .reverse)]) private var timeSections: SectionedResults<String, ShazamStream>
    
    @SectionedQuery(\.placeGroupedString, sort: [SortDescriptor(\.timestamp, order: .reverse)]) private var placeSections: SectionedResults<String, ShazamStream>
    
    var body: some View {
        MapView(shazams: filtered, position: $position)
            .inspector(isPresented: .constant(true)) {
                SheetView(searchText: $searchText, viewBy: $viewBy, filtered: filtered, sections: viewBy == .time ? timeSections : placeSections)
                    .presentationDetents([.height(65), .fraction(0.50), .large], selection: $vm.selectedDetent)
                    .presentationBackgroundInteraction(.enabled)
                    .interactiveDismissDisabled()
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
