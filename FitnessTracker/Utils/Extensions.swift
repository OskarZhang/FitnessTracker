//
//  Extensions.swift
//  FitnessTracker
//
//  Created by Oskar Zhang on 10/16/25.
//
import SwiftUI
import UIKit

enum AppAccentColor: String, CaseIterable, Identifiable {
    static let storageKey = "appAccentColorID"

    case brat = "brat_green"
    case ocean = "ocean_blue"
    case sunset = "sunset_orange"
    case cherry = "cherry_red"
    case orchid = "orchid_pink"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .brat: return "Brat Green"
        case .ocean: return "Ocean Blue"
        case .sunset: return "Sunset Orange"
        case .cherry: return "Cherry Red"
        case .orchid: return "Orchid Pink"
        }
    }

    var color: Color {
        Color(uiColor: uiColor)
    }

    var uiColor: UIColor {
        switch self {
        case .brat:
            return UIColor(red: 138/255, green: 206/255, blue: 0, alpha: 1.0)
        case .ocean:
            return UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1.0)
        case .sunset:
            return UIColor(red: 255/255, green: 111/255, blue: 15/255, alpha: 1.0)
        case .cherry:
            return UIColor(red: 214/255, green: 45/255, blue: 74/255, alpha: 1.0)
        case .orchid:
            return UIColor(red: 189/255, green: 74/255, blue: 255/255, alpha: 1.0)
        }
    }

    static func fromStoredValue(_ value: String) -> AppAccentColor {
        AppAccentColor(rawValue: value) ?? .brat
    }
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
