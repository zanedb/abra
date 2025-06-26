//
//  SongSheet.swift
//  Abra
//

import Kingfisher
import SwiftUI

struct SongSheet: View {
    @Environment(\.colorScheme) var colorScheme
    
    var stream: ShazamStream
    var height: CGFloat
    
    var imageSize: CGFloat {
        height > 100 ? 96 : 48
    }
    
    var body: some View {
        HStack(alignment: .top) {
            KFImage(stream.artworkURL)
                .resizable()
                .placeholder { ProgressView() }
                .aspectRatio(contentMode: .fit)
                .frame(width: imageSize, height: imageSize)
                .cornerRadius(3.0)
                .padding(.trailing, 5)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(stream.title)
                    .fontWeight(.bold)
                    .font(.system(size: 18))
                    .padding(.bottom, 2)
                    .lineLimit(2)
                    .frame(maxWidth: 180, alignment: .leading)
                Text(stream.artist)
                    .foregroundColor(.gray)
                    .font(.system(size: 15))
                    .padding(.bottom, 3)
                
                Spacer()
                
                if let id = stream.appleMusicID {
                    PlayButton(appleMusicID: id)
                }
            }
            
            Spacer()
        }
        .frame(height: 96)
    }
}

#Preview {
    ModelContainerPreview(PreviewSampleData.inMemoryContainer) {
        SongSheet(stream: .preview, height: 100)
            .padding()
    }
}
