//
//  SpotsList.swift
//  Abra
//

import SwiftUI
import SwiftData

struct SpotsList: View {
    @Environment(\.modelContext) private var modelContext
    
//    @Query(sort: \Spot.updatedAt, order: .reverse)
    var spots: [Spot]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Spots")
                    .foregroundColor(.gray)
                    .bold()
                    .font(.system(size: 14))
                Spacer()
                
//                Button("More") {
//                    print("me")
//                }
//                    .font(.system(size: 14))
            }
            .padding(.horizontal)
            .padding(.top, 15)
            .padding(.bottom, 5)
            
            ScrollView(.horizontal) {
                list
            }
            .frame(maxHeight: 96)
            .background(.gray.opacity(0.10))
            .cornerRadius(5)
            .padding(.horizontal)
        }
    }
    
    private var list: some View {
        LazyHStack {
            ForEach(spots, id: \.id) { spot in
                NavigationLink {
                    SpotView(spot: spot)
                        .navigationTitle(spot.name)
                        .onAppear {
//                            vm.updateCenter(spot.latitude, spot.longitude)
                        }
                } label: {
                    VStack(alignment: .center) {
                        Image(systemName: spot.iconName)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .padding(12)
                            .foregroundColor(.white)
                            .background(.indigo) // TODO: allow user color selection
                            .cornerRadius(500)
                        Text(spot.name)
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                        .frame(width: 54)
                        .contextMenu {
                            Button(action: { }) { // TODO: make these work
                                Label("Open Playlist", systemImage: "arrow.up.forward.app.fill")
                            }
                            Button(action: { }) {
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
                // TODO handle error
                print(error.localizedDescription)
            }
        }
    }
}

#Preview {
    SpotsList(spots: [Spot.preview])
}
