//
//  SheetView.swift
//  abra
//
//  Created by Zane on 6/17/23.
//

import SwiftUI

struct SheetView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @State var search: String = ""
    var streams: FetchedResults<SStream>
    
    @ObservedObject var shazam: Shazam
    
    var searchResults: [SStream] {
        if (search.isEmpty) {
            return streams
        } else {
            return streams.filter {
                $0.trackTitle!.localizedCaseInsensitiveContains(search)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            SearchBar(prompt: "Search Shazams…", search: $search, shazam: shazam)
                .padding(.horizontal)
            
            HStack {
                Text("Recent Shazams")
                    .foregroundColor(.gray)
                    .bold()
                    .font(.system(size: 14))
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            List {
                ForEach(searchResults, id: \.self) { stream in
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
        }
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
        SheetView(streams: [SStream.example, SStream.example], shazam: Shazam())
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
