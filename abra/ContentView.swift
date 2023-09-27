//
//  ContentView.swift
//  abra
//
//  Created by Zane on 6/5/23.
//

import SwiftUI
import SwiftData
import SectionedQuery
import MapKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var vm: ViewModel
    
    @State var searchText: String = ""
    @State var viewBy: ViewBy = .time
    
    @Query(sort: \ShazamStream.timestamp, order: .reverse)
    var shazams: [ShazamStream]
    
    var filtered: [ShazamStream] {
        guard searchText.isEmpty == false else { return shazams }
        
        return shazams.filter { $0.title.lowercased().contains(searchText.lowercased()) }
    }
    
    @SectionedQuery(
        sectionIdentifier: \ShazamStream.timeGroupedString,
                    sortDescriptors: [SortDescriptor(\ShazamStream.timestamp, order: .reverse)],
                    predicate: nil,
                    animation: .default
    )
    private var timeSections
    
    @SectionedQuery(
        sectionIdentifier: \ShazamStream.placeGroupedString,
                    sortDescriptors: [SortDescriptor(\ShazamStream.timestamp, order: .reverse)],
                    predicate: nil,
                    animation: .default
    )
    private var placeSections
    
    var body: some View {
        ZStack(alignment: .top) {
            MapView()
                .inspector(isPresented: .constant(true)) {
                    SheetView(navPath: $navPath, searchText: $searchText, viewBy: $viewBy, filtered: filtered, sections: viewBy == .time ? timeSections : placeSections)
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
    // .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
    // .previewDisplayName("iPad Pro 12.9")
}
