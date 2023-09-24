//
//  SongList.swift
//  abra
//
//  Created by Zane on 6/22/23.
//

import SwiftUI

struct SongList: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var vm: ViewModel
    
    var body: some View {
        List {
            ForEach(vm.streams, id: \.self) { stream in
                NavigationLink {
                    SongView(stream: stream)
                        .navigationTitle(stream.timestamp?.formatted(.dateTime.weekday().day().month()) ?? "Shazam")
                        .toolbar {
                            ToolbarItem() {
                                Menu {
                                    ShareLink(item: stream.appleMusicURL!) {
                                        Label("Apple Music", systemImage: "arrow.up.forward.square")
                                    }
                                    Button(action: { }) { // TODO: generate preview image
                                        Label("Preview", systemImage: "photo.stack")
                                    }
                                } label: {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                        .onAppear {
                            vm.updateCenter(stream.latitude, stream.longitude)
                        }
                } label: {
                    SongRow(stream: stream)
                        .contextMenu {
                            Link(destination: stream.appleMusicURL!) {
                                Label("Open in Apple Music", systemImage: "arrow.up.forward.app.fill")
                            }
                            ShareLink(item: stream.appleMusicURL!) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            Divider()
                            Button(role: .destructive, action: { deleteStream(stream) }, label: {
                                Label("Remove", systemImage: "trash")
                            })
                        }
                }
            }
            .onDelete(perform: deleteStreams)
        }
        .listStyle(.inset)
        .padding(.top, 0)
    }
    
    private func deleteStreams(offsets: IndexSet) {
        withAnimation {
            offsets.map { vm.streams[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func deleteStream(_ stream: SStream) {
        withAnimation {
            viewContext.delete(stream)
        
            do {
                try viewContext.save()
            } catch {
                // TODO handle error
                print(error.localizedDescription)
            }
        }
    }
}

struct SongList_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
