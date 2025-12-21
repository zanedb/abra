//
//  SongDetails.swift
//  Abra
//
//  Created by Zane Davis-Barrs on 12/20/25.
//

import SwiftUI

struct SongDetails: View {
    var stream: ShazamStream

    @State private var note: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("When")
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(stream.timestamp.looseDescription())
                        //.font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(
                            stream.timestamp,
                            format: stream.timestamp.isThisYear
                                ? .dateTime.day().month()
                                : .dateTime.day().month().year()
                        )
                        Text("·")
                        Text(stream.timestamp, style: .time)
                    }
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text("Notes")
                .foregroundStyle(.secondary)
            TextField("Add Note", text: $note)
                .padding(.top, -4)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

#Preview {
    VStack {}
        .sheet(isPresented: .constant(true)) {
            SongView(stream: .preview)
                // .presentationDetents([.medium, .large])
                .environment(SheetProvider())
                .environment(LibraryProvider())
                .environment(MusicProvider())
                .environment(LocationProvider())
                .environment(ShazamProvider())
        }
}
