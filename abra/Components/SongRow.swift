//
//  SongRow.swift
//  abra
//
//  Created by Zane on 6/6/23.
//

import SwiftUI
import CoreData
import SDWebImageSwiftUI

struct SongRow: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var stream: SStream
    
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
                Text(stream.trackTitle ?? "Unknown Song")
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.80) : Color.black.opacity(0.80))
                    .font(.system(size: 17))
                    .padding(.bottom, 3)
                Text(stream.artist ?? "Unknown Artist")
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6))
                    .font(.system(size: 14))
                    .padding(.bottom, 3)
                Text(stream.timestamp?.formatted(.dateTime.day().month().hour().minute()) ?? "Something went wrong")
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
    var stream: SStream
    
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
                    Text(stream.trackTitle ?? "?")
                        .font(.body)
                        .lineLimit(1)
                        .padding(.trailing, stream.explicitContent ? -3.0 : 0)
                    if stream.explicitContent {
                        Image(systemName: "e.square.fill")
                            .padding(.horizontal, 0)
                            .foregroundColor(Color.gray)
                            .accessibilityLabel("Explicit")
                            .imageScale(.small)
                    }
                }
                .padding(.bottom, -5)
                .padding(.trailing, 16)
                
                Text(stream.artist ?? "?")
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
                    .lineLimit(1)
            }
            
            Spacer()
        }
    }
}

struct SongRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            SongRow(stream: SStream.example)
                .padding()
            SongRowMini(stream: SStream.example)
                .padding()
        }
    }
}
