//
//  Wrapper.swift
//  Abra
//

import SwiftUI

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

