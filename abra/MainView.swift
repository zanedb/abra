//
//  MainView.swift
//  abra
//
//  Created by Zane on 6/5/23.
//

import SwiftUI
import CoreData

struct MainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SStream.timestamp, ascending: false)],
        animation: .default)
    private var streams: FetchedResults<SStream>
    
    @ObservedObject private var shazam = Shazam()
    
    @State private var pulseAmount: CGFloat = 1
    
    var body: some View {
        NavigationStack {
            VStack {
                Button(action: { shazam.searching ? shazam.stopRecognition() : shazam.startRecognition() }) {
                    Image(systemName: "shazam.logo.fill")
                        .symbolRenderingMode(.multicolor)
                        .tint(Color.blue)
                        .fontWeight(.medium)
                        .font(.system(size: 156))
                        .padding(.vertical)
                        .cornerRadius(100)
                        .scaleEffect(pulseAmount)
                        .onChange(of: shazam.searching) { done in
                            if done {
                                startAnimation()
                            } else {
                                stopAnimation()
                            }
                        }
                }
                Text(shazam.searching ? "Listening…" : "Tap to Shazam")
                    .fontWeight(.medium)
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6))
                    .font(.system(size: 18))
                    .padding(.bottom)
            }
            
            if (!streams.isEmpty) {
                Divider()
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
                .listStyle(.inset)
            }
        }
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

// todo make a button component and move this logic there
private extension MainView {
    func startAnimation() {
        withAnimation(Animation.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.8).repeatForever(autoreverses: true)) {
            pulseAmount = 1.02
        }
    }
    
    func stopAnimation() {
        withAnimation {
            pulseAmount = 1
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
