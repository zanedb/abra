//
//  NoResults.swift
//  abra
//
//  Created by Zane on 6/22/23.
//

import SwiftUI

struct NoResults: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "moon.stars")
                .foregroundColor(.blue.opacity(0.70))
                .font(.system(size: 48))
                .padding(.top, 50)
            Text("No Results")
                .padding(.top, 40)
                .bold()
                .foregroundColor(.primary)
                .font(.system(size: 22))
            Text("Try a new search.")
                .padding(.top, 10)
                .foregroundColor(.gray)
                .font(.system(size: 18))
        }
        .frame(maxHeight: .infinity)
    }
}

struct NoResults_Previews: PreviewProvider {
    static var previews: some View {
        NoResults()
    }
}
