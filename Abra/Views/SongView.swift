//
//  SongView.swift
//  Abra
//

import MapKit
import SwiftData
import SwiftUI

struct SongView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(LibraryProvider.self) private var library
    @Environment(MusicProvider.self) private var music
    
    var stream: ShazamStream
    var newSpotCallback: ((SpotType) -> Void)?
    
    @State private var scrollOffset: CGFloat = 0
    private let transitionThreshold: CGFloat = 5
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top toolbar - visible when scrolled
            toolbar(showTitle: true)
                .opacity(topToolbarOpacity)
                .offset(y: topToolbarOffset)
                .frame(height: topToolbarOpacity > 0.01 ? nil : 0)
                .clipped()
                .animation(.easeInOut(duration: 0.25), value: scrollOffset)
            
            ScrollView {
                // Scroll tracking view at the very top
                GeometryReader { proxy in
                    let minY = proxy.frame(in: .named("scrollView")).minY
                    Color.clear
                        .onAppear {
                            print("Initial scroll position: \(minY)")
                        }
                        .onChange(of: minY) { _, newValue in
                            scrollOffset = newValue
                            print("Scroll offset: \(newValue)")
                        }
                }
                .frame(height: 1)
                
                SongSheet(stream: stream)
                    .padding(.top)
                    .overlay(alignment: .top) {
                        // Overlay toolbar - visible when not scrolled
                        toolbar(showTitle: false)
                            .opacity(overlayToolbarOpacity)
                            .animation(.easeInOut(duration: 0.3), value: scrollOffset)
                    }
                
                SongInfo(stream: stream, newSpotCallback: newSpotCallback)
                    .padding(.top)
                    .padding(.bottom, 4)
                
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.background)
                        .clipShape(RoundedRectangle(
                            cornerRadius: 14
                        ))
                    
                    VStack(alignment: .leading) {
                        Text("You’ve discovered this song before.")
                            .font(.system(size: 17, weight: .medium))
                        
                        Text("August 14 in San Francisco")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
                
                if !library.hasIgnoredPhotosRequest {
                    HStack {
                        Text(stream.timestamp, style: .date)
                            .font(.headline)
                        
                        Spacer()
                        
                        Text(stream.timestamp, style: .time)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    .padding(.bottom, 8)
                    
                    Photos(stream: stream)
                }
                
                Spacer()
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
        }
        .padding()
        .task {
            await music.authorize()
        }
    }
    
    // Computed properties for smooth transitions
    private var topToolbarOpacity: Double {
        let progress = max(0, min(1, -scrollOffset / transitionThreshold))
        return progress
    }
        
    private var overlayToolbarOpacity: Double {
        let progress = max(0, min(1, -scrollOffset / transitionThreshold))
        return 1 - progress
    }
        
    private var topToolbarOffset: CGFloat {
        let progress = max(0, min(1, -scrollOffset / transitionThreshold))
        return (1 - progress) * -30
    }
    
    private func toolbar(showTitle: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            if showTitle {
                Text(stream.title)
                    .fontWeight(.bold)
                    .font(.system(size: 18))
                    .lineLimit(1)
            }
                
            Spacer()
                
            if stream.appleMusicURL != nil {
                ShareLink(item: stream.appleMusicURL!) {
                    Label("Share", systemImage: "square.and.arrow.up.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundColor(.gray)
                        .font(.system(size: 32))
                        .symbolRenderingMode(.hierarchical)
                }
            }
                
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.system(size: 32))
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .padding(.bottom, 12)
    }
}

// PreferenceKey to track scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ShazamStream.self, configurations: config)
    
    struct ContentView: View {
        @State private var showSheet = true
        let stream = ShazamStream.preview
        
        var body: some View {
            EmptyView()
                .inspector(isPresented: $showSheet) {
                    SongView(stream: stream)
                        .environment(LibraryProvider())
                        .environment(MusicProvider())
                }
        }
    }
    
    return ContentView()
        .modelContainer(container)
}
