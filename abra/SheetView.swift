//
//  SheetView.swift
//  abra
//
//  Created by Zane on 6/17/23.
//

import SwiftUI

struct SheetView: View {
    @State var search: String = ""
    var streams: FetchedResults<SStream>
    
    @ObservedObject var shazam: Shazam
    @Binding var detent: PresentationDetent
    @FocusState var focused: Bool
    
    var onSongTapped: (SStream) -> ()
    
    var body: some View {
        NavigationStack {
            VStack {
                SearchBar(prompt: "Search Shazams…", search: $search, focused: _focused, shazam: shazam)
                    .padding(.horizontal)
                    .padding(.top, (detent != PresentationDetent.height(65) || focused) ? 14 : 0)
                
                if (detent != PresentationDetent.height(65) || focused) {
                    VStack(spacing: 0) {
                        if (!search.isEmpty && streams.isEmpty) {
                            NoResults()
                        } else {
                            HStack(spacing: 0) {
                                Text(search.isEmpty ? "Recent Shazams" : "Search Results")
                                    .foregroundColor(.gray)
                                    .bold()
                                    .font(.system(size: 14))
                                    .id("Descriptor" + (search.isEmpty ? "Library" : "Search"))
                                    .transition(.opacity.animation(.easeInOut(duration: 0.075)))
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 15)
                        }
                        
                        SongList(streams: streams, detent: $detent, onSongTapped: onSongTapped)
                    }
                    .transition(.asymmetric(
                        insertion: .push(from: .bottom).animation(.easeInOut(duration: 0.25)),
                        removal: .opacity.animation(.easeInOut(duration: 0.15)))
                    )
                }
            }
                .toolbar(.hidden)
                .onChange(of: search) { newValue in
                    streams.nsPredicate = newValue.isEmpty ? nil : NSPredicate(format: "trackTitle CONTAINS[c] %@", newValue)
                }
                .navigationTitle("Library")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct NoResults: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "moon.stars")
                .foregroundColor(.blue.opacity(0.70))
                .font(.system(size: 48))
                .padding(.top, 50)
            Text("No Results")
                .padding(.top, 40)
                .bold()
                .foregroundColor(.primary)
                .font(.system(size: 22))
            Text("Try a new search.")
                .padding(.top, 10)
                .foregroundColor(.gray)
                .font(.system(size: 18))
        }
        .frame(maxHeight: .infinity)
    }
}

struct SongList: View {
    @Environment(\.managedObjectContext) private var viewContext
    var streams: FetchedResults<SStream>
    @Binding var detent: PresentationDetent
    var onSongTapped: (SStream) -> Void
    
    var body: some View {
        List {
            ForEach(streams, id: \.self) { stream in
                NavigationLink {
                    SongView(stream: stream, detent: $detent)
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
                            onSongTapped(stream)
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
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
