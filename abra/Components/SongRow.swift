//
//  SongRow.swift
//  abra
//
//  Created by Zane on 6/6/23.
//

import SwiftUI
import SDWebImageSwiftUI

struct SongRow: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var stream: ShazamStream
    
    var body: some View {
        HStack {
            WebImage(url: stream.artworkURL)
                .resizable()
                .placeholder {
                    ProgressView()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .padding(.trailing, 5)
                }
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .cornerRadius(3.0)
                .padding(.trailing, 5)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(stream.title)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.80) : Color.black.opacity(0.80))
                    .font(.system(size: 17))
                    .padding(.bottom, 3)
                Text(stream.artist)
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6))
                    .font(.system(size: 14))
                    .padding(.bottom, 3)
                Text(stream.timestamp.formatted(.dateTime.day().month().hour().minute()))
                    .foregroundColor(Color.gray)
                    .font(.system(size: 13))
                Spacer()
                Text((stream.city ?? "Invalid location") + ", " + (stream.countryCode ?? "oops!"))
                    .foregroundColor(Color.gray)
                    .font(.system(size: 12))
            }
            Spacer()
        }
        .frame(height: 96)
    }
}

struct SongRowMini: View {
    var stream: ShazamStream
    
    var body: some View {
        HStack {
            WebImage(url: stream.artworkURL)
                .resizable()
                .placeholder {
                    ProgressView()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .padding(.trailing, 5)
                }
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
                .padding(.bottom, -5)
                .padding(.trailing, 16)
                
                Text(stream.artist)
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
                    .lineLimit(1)
            }
            
            Spacer()
        }
    }
}

#Preview {
    ModelContainerPreview(PreviewSampleData.inMemoryContainer) {
        VStack {
            SongRow(stream: .preview)
                .padding()
            SongRowMini(stream: .preview)
                .padding()
        }
    }
}
