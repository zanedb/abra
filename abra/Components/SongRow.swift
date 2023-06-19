//
//  SongRow.swift
//  abra
//
//  Created by Zane on 6/6/23.
//

import SwiftUI
import CoreData

struct SongRow: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var stream: SStream
    
    var body: some View {
        HStack {
            AsyncImage(
                url: stream.artworkURL,
                content: { image in
                    image.resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .cornerRadius(/*@START_MENU_TOKEN@*/3.0/*@END_MENU_TOKEN@*/)
                    .padding(.trailing, 5)
                },
                placeholder: {
                    ProgressView()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .padding(.trailing, 5)
                }
            )
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

struct SongRow_Previews: PreviewProvider {
    static var previews: some View {
        SongRow(stream: SStream.example)
            .padding()
    }
}
