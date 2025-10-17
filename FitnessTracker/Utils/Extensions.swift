//
//  Extensions.swift
//  FitnessTracker
//
//  Created by Oskar Zhang on 10/16/25.
//
import SwiftUI
import UIKit

extension UIColor {
    static let bratGreen = UIColor(red: 138/255, green: 206/255, blue: 0, alpha: 1.0)
}

extension Color {
    static let bratGreen = Color(uiColor: .bratGreen)
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let enabled: Bool

    @State private var startPoint = UnitPoint(x: -0.2, y: -0.2)
    @State private var endPoint = UnitPoint(x: 0, y: 0)
    func body(content: Content) -> some View {
        if enabled {
            content
                .mask(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.3),
                            Color.black,
                            Color.black.opacity(0.3)
                        ]),
                        startPoint: startPoint,
                        endPoint: endPoint
                    )
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now()) {
                            withAnimation(
                                Animation.linear(duration: 2.0)
                                    .repeatForever(autoreverses: false)
                            ) {
                                startPoint = UnitPoint(x: 1.2, y: 1.2)
                                endPoint = UnitPoint(x: 1, y: 1)
                            }
                        }
                    }
                )
        } else {
            content
        }
    }
}

extension View {
    func shimmer(enabled: Bool) -> some View {
        modifier(ShimmerModifier(enabled: enabled))
    }
}
