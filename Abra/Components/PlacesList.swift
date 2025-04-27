//
//  PlacesList.swift
//  Abra
//

import SwiftUI
import SwiftData

struct PlacesList: View {
    @Environment(\.modelContext) private var modelContext
    
//    @Query(sort: \Place.updatedAt, order: .reverse)
    var places: [Place]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Places")
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
            ForEach(places, id: \.id) { place in
                NavigationLink {
                    PlaceView(place: place)
                        .navigationTitle(place.name)
                        .onAppear {
//                            vm.updateCenter(place.latitude, place.longitude)
                        }
                } label: {
                    VStack(alignment: .center) {
                        Image(systemName: place.iconName)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .padding(12)
                            .foregroundColor(.white)
                            .background(.indigo) // TODO: allow user color selection
                            .cornerRadius(500)
                        Text(place.name)
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
                            Button(role: .destructive, action: { deletePlace(place) }, label: {
                                Label("Remove", systemImage: "trash")
                            })
                        }
                }
            }
        }
        .padding(.leading, 5)
        .padding(.horizontal, 10)
    }
    
    private func deletePlaces(offsets: IndexSet) {
        withAnimation {
            offsets.map { places[$0] }.forEach(modelContext.delete)

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
    
    private func deletePlace(_ place: Place) {
        withAnimation {
            modelContext.delete(place)
        
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
    PlacesList(places: [Place.preview])
}
