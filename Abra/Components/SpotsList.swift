//
//  SpotsList.swift
//  Abra
//

import SwiftData
import SwiftUI

struct SpotsList: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SheetProvider.self) private var view
    
    @Query(sort: \Spot.updatedAt, order: .reverse)
    private var spots: [Spot]
    
    var body: some View {
        if spots == [] {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("Spots")
                        .foregroundColor(.gray)
                        .bold()
                        .font(.system(size: 14))
                    Spacer()
                    
                    //                Button("More") { }
                    //                .font(.system(size: 14))
                }
                .padding(.bottom, 8)
                
                ScrollView(.horizontal) {
                    list
                }
                .frame(maxHeight: 96)
                .background(.background)
                .cornerRadius(14)
            }
        }
    }
    
    private var list: some View {
        LazyHStack {
            ForEach(spots, id: \.id) { spot in
                Button {
                    view.spot = spot
                } label: {
                    VStack(alignment: .center) {
                        Image(systemName: spot.iconName)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .padding(12)
                            .foregroundColor(.white)
                            .background(.indigo)
                            .cornerRadius(500)
                        Text(spot.name)
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    .frame(width: 54)
                    .contextMenu {
                        Button(action: {}) { // TODO: make these work
                            Label("Open Playlist", systemImage: "arrow.up.forward.app.fill")
                        }
                        Button(action: {}) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        Button(role: .destructive, action: { deleteSpot(spot) }, label: {
                            Label("Remove", systemImage: "trash")
                        })
                    }
                }
            }
        }
        .padding(.leading, 5)
        .padding(.horizontal, 10)
    }
    
    private func deleteSpots(offsets: IndexSet) {
        withAnimation {
            offsets.map { spots[$0] }.forEach(modelContext.delete)

            do {
                try modelContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func deleteSpot(_ spot: Spot) {
        withAnimation {
            modelContext.delete(spot)
        
            do {
                try modelContext.save()
            } catch {
                // TODO: handle error
                print(error.localizedDescription)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            SpotsList()
                .modelContainer(PreviewSampleData.container)
                .environment(SheetProvider())
                .padding()
        }
        .background(.ultraThickMaterial)
    }
}
