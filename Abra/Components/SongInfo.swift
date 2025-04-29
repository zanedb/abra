//
//  SongInfo.swift
//  Abra
//

import SwiftUI

struct SongInfo: View {
    var stream: ShazamStream
    
    var body: some View {
        VStack(alignment: .leading) {
            Divider()
            
            HStack(alignment: .center) {
                stat("Speed", Text("\(stream.speed ?? 0)"))
                
                Divider()
                    .frame(height: 30)
                    .padding(.horizontal, 6)
                
                stat("Altitude", Text("\(stream.altitude ?? 0)"))
                
                Divider()
                    .frame(height: 30)
                    .padding(.horizontal, 6)
                
                stat(
                    "Place",
                    Button(action: {}) {
                        Image(systemName: "mappin.and.ellipse")
                        Text("Choose")
                            .padding(.leading, -5)
                    }
                    .accessibilityLabel("Choose Place")
                )
            }
            .padding(.bottom, 4)
            .padding(.top, 2)
            
            Divider()
        }
        .padding(.top)
    }
    
    func stat(_ label: String, _ value: some View) -> some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(Font.system(.body).smallCaps())
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            value
        }
    }
}

#Preview {
    ModelContainerPreview(PreviewSampleData.inMemoryContainer) {
        SongInfo(stream: .preview)
            .padding()
    }
}
