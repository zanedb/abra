//
//  SongSheet.swift
//  abra
//
//  Created by Zane on 6/7/23.
//

import SwiftUI

struct SongSheet: View {
    @Environment(\.colorScheme) var colorScheme
    
    var stream: ShazamStream
    
    var body: some View {
        HStack {
            AsyncImage(url: stream.artworkURL) { image in
                image
                    .resizable()
            } placeholder: {
                ProgressView()
                    .scaledToFit()
            }
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .cornerRadius(3.0)
                .padding(.trailing, 5)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(stream.title)
                    .fontWeight(.bold)
                    .font(.system(size: 18))
                    .padding(.bottom, 2)
                    .lineLimit(2)
                Text(stream.artist)
                    .foregroundColor(.gray)
                    .font(.system(size: 15))
                    .padding(.bottom, 3)
                
                Spacer()
                
                if (stream.appleMusicID != nil) {
                    PlayButton(appleMusicID: stream.appleMusicID!)
                }
            }
        }
            .frame(height: 96)
    }
}

#Preview {
    ModelContainerPreview(PreviewSampleData.inMemoryContainer) {
        SongSheet(stream: .preview)
            .padding()
    }
}
