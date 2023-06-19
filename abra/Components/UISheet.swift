//
//  UISheet.swift
//  abra
//
//  Created by Zane on 6/17/23.
//

import Foundation
import UIKit
import SwiftUI

class UISheetController<Content>: UIHostingController<Content> where Content : View {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let presentation = sheetPresentationController {
            let smallDetentId = UISheetPresentationController.Detent.Identifier("small")
            let smallDetent = UISheetPresentationController.Detent.custom(identifier: smallDetentId) { context in
                return 75
            }
            
            let mediumDetentId = UISheetPresentationController.Detent.Identifier("medium")
            let mediumDetent = UISheetPresentationController.Detent.custom(identifier: mediumDetentId) { context in
                return context.maximumDetentValue * 0.45
            }
            
            presentation.detents = [smallDetent, mediumDetent, .large()]
            presentation.selectedDetentIdentifier = mediumDetentId
            presentation.prefersScrollingExpandsWhenScrolledToEdge = false
            presentation.largestUndimmedDetentIdentifier = .large
            presentation.prefersGrabberVisible = true
        }
    }
}

struct UISheet<Content>: UIViewControllerRepresentable where Content : View {
    private let content: Content
    
    @inlinable init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    func makeUIViewController(context: Context) -> UISheetController<Content> {
        return UISheetController(rootView: content)
    }
    
    func updateUIViewController(_: UISheetController<Content>, context: Context) {

    }
}


struct SizePreferenceKey: PreferenceKey {
  static var defaultValue: CGSize = .zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

extension View {
  func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
    background(
      GeometryReader { geometryProxy in
        Color.clear
          .preference(key: SizePreferenceKey.self, value: geometryProxy.size)
      }
    )
    .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
  }
}
