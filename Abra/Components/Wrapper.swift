//
//  Wrapper.swift
//  Abra
//

import SwiftUI
import _MapKit_SwiftUI

struct Wrapper<Content: View>: View {
    let padding: Bool
    let content: Content

    init(padding: Bool = true, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.quinary)
                .clipShape(.rect(cornerRadius: 18))

            if padding {
                content
                    .padding()
            } else {
                content
            }
        }
    }
}

#Preview {
    VStack {}
        .sheet(isPresented: .constant(true)) {
            SongView(stream: .preview)
                .environment(SheetProvider())
                .environment(LibraryProvider())
                .environment(MusicProvider())
                .environment(LocationProvider())
                .environment(ShazamProvider())
        }
}

#Preview {
    Map()
        .sheet(isPresented: .constant(true)) {
            VStack {
                Wrapper {
                    HStack {
                        Image(systemName: "list.bullet.indent")
                        Text("3 songs by Denzel Curry in library.")
                    }
                    .font(.callout)
                    .frame(height: 50)
                }
                Spacer()
            }
            .presentationDetents([.fraction(0.50), .large])
            .presentationInspector()
            .edgesIgnoringSafeArea(.bottom)
            .prefersEdgeAttachedInCompactHeight()
        }
}
