//
//  SongRow.swift
//  Abra
//

import Kingfisher
import SwiftUI

struct SongRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(ShazamProvider.self) private var shazam
    
    var stream: ShazamStream
    
    var body: some View {
        HStack {
            KFImage(stream.artworkURL)
                .cancelOnDisappear(true)
                .resizable()
                .placeholder { ProgressView() }
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .cornerRadius(3.0)
                .padding(.trailing, 5)
            
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(stream.title)
                        .fontWeight(.bold)
                        .font(.system(size: 17))
                        .padding(.bottom, 3)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Text(stream.relativeDateTime)
                        .foregroundColor(Color.gray)
                        .font(.system(size: 13))
                }
                Text(stream.artist)
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
                    .padding(.bottom, 3)
                
                Spacer()
                
                Text(stream.cityState)
                    .foregroundColor(Color.gray)
                    .font(.system(size: 14))
            }
            Spacer()
        }
        .frame(height: 96)
        .contextMenu {
            if stream.appleMusicURL != nil {
                Link(destination: stream.appleMusicURL!) {
                    Label("Open in Apple Music", systemImage: "arrow.up.forward.app.fill")
                }
                ShareLink(item: stream.appleMusicURL!) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Divider()
            }
            Button(role: .destructive, action: { deleteStream() }, label: {
                Label("Remove", systemImage: "trash")
            })
        }
    }
    
    private func deleteStream() {
        withAnimation {
            modelContext.delete(stream)
            try? modelContext.save()
        }
        Task {
            try? await shazam.removeFromLibrary(stream: stream)
        }
    }
}

struct SongRowMini: View {
    @Environment(SheetProvider.self) var view
    
    var stream: ShazamStream
    
    var body: some View {
        HStack {
            KFImage(stream.artworkURL)
                .cancelOnDisappear(true)
                .resizable()
                .placeholder { ProgressView() }
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
                .cornerRadius(3.0)
                .padding(.trailing, 5)
                
            VStack(alignment: .leading) {
                HStack {
                    Text(stream.title)
                        .font(.body)
                        .lineLimit(1)
                        .padding(.trailing, stream.isExplicit ? -3.0 : 0)
                    if stream.isExplicit {
                        Image(systemName: "e.square.fill")
                            .padding(.horizontal, 0)
                            .foregroundColor(Color.gray)
                            .accessibilityLabel("Explicit")
                            .imageScale(.small)
                    }
                }
                .padding(.trailing, 16)
                
                Text(stream.artist)
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .frame(maxHeight: 44)
        .contextMenu {
            if stream.appleMusicURL != nil {
                Link(destination: stream.appleMusicURL!) {
                    Label("Open in Apple Music", systemImage: "arrow.up.forward.app.fill")
                }
                ShareLink(item: stream.appleMusicURL!) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
                
            Divider()
                
            Button(action: {
                view.stream = stream
                view.spot = nil
            }) {
                Label("View", systemImage: "arrow.up.forward")
            }
        }
    }
}

#Preview {
    ModelContainerPreview(PreviewSampleData.inMemoryContainer) {
        VStack(alignment: .leading) {
            SongRow(stream: .preview)
                .padding()
            
            Text("Discovered")
                .font(.subheadline)
                .bold()
                .foregroundColor(.gray)
                .padding(.horizontal)
                .padding(.top, 12)
            EditableList(Binding(get: { [ShazamStream.preview, ShazamStream.preview] }, set: { _ in })) { $stream in
                SongRowMini(stream: stream)
            }
            .listStyle(.plain)
        }
        .environment(ShazamProvider())
        .environment(SheetProvider())
    }
}
