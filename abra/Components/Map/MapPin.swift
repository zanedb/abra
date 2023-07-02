//
//  MapPin.swift
//  abra
//
//  Created by Zane on 7/2/23.
//

import SwiftUI
import SDWebImageSwiftUI

struct MapPin: View {
    var stream: SStream
    
    var body: some View {
        ZStack {
            DropPin()
                .frame(width: 33, height: 50)
                .foregroundColor(.red.opacity(0.80))
                .shadow(color: .black.opacity(0.50), radius: 3, x: 1, y: 2)
            WebImage(url: stream.artworkURL)
                .resizable()
                .placeholder {
                    ProgressView()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                }
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .clipShape(Circle())
        }
    }
}

struct ClusterPin: View {
    var count: Int
    
    var body: some View {
        ZStack {
            DropPin()
                .frame(width: 33, height: 50)
                .foregroundColor(.red.opacity(0.80))
                .foregroundStyle(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.40), radius: 3, x: 1, y: 2)
            Text("\(count)")
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .clipShape(Circle())
        }
    }
}

struct DropPin: Shape {
    var startAngle: Angle = .degrees(180)
    var endAngle: Angle = .degrees(0)

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.midY),
                      control1: CGPoint(x: rect.midX, y: rect.maxY),
                      control2: CGPoint(x: rect.minX, y: rect.midY + rect.height / 4))
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                      control1: CGPoint(x: rect.maxX, y: rect.midY + rect.height / 4),
                      control2: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

struct MapPin_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            MapPin(stream: SStream.example)
            ClusterPin(count: 5)
            ClusterPin(count: 15)
            ClusterPin(count: 150)
            ClusterPin(count: 150)
        }
    }
}
