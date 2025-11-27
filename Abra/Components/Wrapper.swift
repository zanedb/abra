//
//  Wrapper.swift
//  Abra
//

import SwiftUI
import _MapKit_SwiftUI

struct Wrapper<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.background)
                .clipShape(.rect(cornerRadius: 14))

            content
                .padding()
        }
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
