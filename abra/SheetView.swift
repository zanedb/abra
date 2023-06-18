//
//  SheetView.swift
//  abra
//
//  Created by Zane on 6/17/23.
//

import SwiftUI

struct SheetView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var streams: [SStream]
    
    @State private var search: String = ""
    
    var body: some View {
        List {
            ForEach(streams, id: \.self) { stream in
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
            .onDelete(perform: deleteStreams)
        }
        .searchable(text: $search, placement: .toolbar, prompt: "Search Shazams…")
        .listStyle(.inset)
    }
    
    private func deleteStreams(offsets: IndexSet) {
        withAnimation {
            offsets.map { streams[$0] }.forEach(viewContext.delete)

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

struct SheetView_Previews: PreviewProvider {
    static var previews: some View {
        SheetView(streams: [SStream.example])
    }
}
