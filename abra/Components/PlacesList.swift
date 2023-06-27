//
//  PlacesList.swift
//  abra
//
//  Created by Zane on 6/22/23.
//

import SwiftUI

struct PlaceTemp: Hashable, Identifiable {
    var id: Int
    var iconName: String?
    var name: String?
    var bgColor: Color?
}

struct PlacesList: View {
    
    //var places: FetchedResults<Place>
    @State var places: [PlaceTemp] = [
        PlaceTemp(id: 0, iconName: "magnifyingglass", name: "Looking Glass", bgColor: Color.red),
        PlaceTemp(id: 1, iconName: "house.fill", name: "Home", bgColor: Color.orange),
        PlaceTemp(id: 2, iconName: "takeoutbag.and.cup.and.straw.fill", name: "Jack's", bgColor: Color.purple),
        PlaceTemp(id: 3, iconName: "building.2.fill", name: "Dorm", bgColor: Color.indigo),
        PlaceTemp(id: 4, iconName: "figure.strengthtraining.traditional", name: "Gym", bgColor: Color.blue),
        PlaceTemp(id: 5, iconName: "testtube.2", name: "Lab", bgColor: Color.green),
        PlaceTemp(id: 6, iconName: "arrow.up", name: "Gamba", bgColor: Color.yellow)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Places")
                    .foregroundColor(.gray)
                    .bold()
                    .font(.system(size: 14))
                Spacer()
                Button("More") {
                    print("me")
                }
                    .font(.system(size: 14))
            }
            .padding(.horizontal)
            .padding(.top, 15)
            .padding(.bottom, 5)
            
            ScrollView(.horizontal) {
                LazyHStack {
                        ForEach(places, id: \.id) { place in
                            VStack(alignment: .center) {
                                Image(systemName: place.iconName ?? "questionmark")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .padding(12)
                                    .foregroundColor(.white)
                                    .background(place.bgColor)
                                    .cornerRadius(500)
                                Text(place.name ?? "Unknown")
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                            .frame(width: 52)
//                            .padding(.trailing, 5)
                        }
                }
                .padding(.leading, 5)
                .padding(.horizontal, 10)
            }
            .frame(maxHeight: 96)
            .background(.gray.opacity(0.10))
            .cornerRadius(5)
            .padding(.horizontal)
            //.padding()
        }
    }
}

struct PlacesList_Previews: PreviewProvider {
    static var previews: some View {
        PlacesList()
    }
}
