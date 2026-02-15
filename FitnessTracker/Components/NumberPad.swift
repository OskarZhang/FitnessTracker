//
//  NumberPad.swift
//  FitnessTracker
//
//  Created by Oskar Zhang on 10/16/25.
//

import SwiftUI

enum RecordType {
    case weight, rep
    func labelForValue(_ value: Int) -> String {
        switch self {
        case .weight:
            return "lb"
        case .rep:
            return value > 1 ? "reps" : "rep"
        }
    }
}


enum NumberEditMode {
    case overwrite
    case append
}


struct OnReturnModifier: ViewModifier {
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content.onSubmit {
            action()
        }
    }
}

struct NumberPad: View {
    @Environment(\.colorScheme) var colorScheme

    let type: RecordType
    var nextAction: (() -> Void)?

    @Binding var value: Int
    
    @Binding private var editMode: NumberEditMode

    init(type: RecordType, value: Binding<Int>, editMode: Binding<NumberEditMode>) {
        self.type = type
        self._value = value
        self._editMode = editMode
    }
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        VStack {
            Divider()
            HStack {
                if type == .weight {
                    quickAddWeightButton(5)
                    quickAddWeightButton(10)
                    quickAddWeightButton(15)
                    quickAddWeightButton(20)
                } else {
                    quickSetReps(10)
                    quickSetReps(12)
                    quickSetReps(15)
                }
            }
            HStack {
                numberButton(1)
                numberButton(2)
                numberButton(3)
            }

            HStack {
                numberButton(4)
                numberButton(5)
                numberButton(6)
            }

            HStack {
                numberButton(7)
                numberButton(8)
                numberButton(9)
            }
            HStack {
                backspaceButton
                numberButton(0)
                if type == .weight {
                    nextButton
                } else {
                    completeSetButton
                }
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .background(colorScheme == .dark ? Color.black : Color(.systemGray5))
    }
    
    @ViewBuilder
    private func quickAddWeightButton(_ weight: Int) -> some View {
        Button {
            lightImpact.impactOccurred()
            
            value += weight
            
        } label: {
            Text("+\(weight) lb")
                .font(.system(size: 24, weight: .medium))
                .styledNumberPadText(height: 40, colorScheme: colorScheme)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    
    @ViewBuilder
    private func quickSetReps(_ reps: Int) -> some View {
        Button {
            lightImpact.impactOccurred()
            value = reps
        } label: {
            Text("\(reps) reps")
                .font(.system(size: 24, weight: .medium))
                .styledNumberPadText(height: 40, colorScheme: colorScheme)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func numberButton(_ number: Int) -> some View {
        Button {
            lightImpact.impactOccurred()
            didTap(number)
        } label: {
            Text("\(number)")
                .font(.system(size: 36, weight: .regular))
                .styledNumberPadText(height: 60, colorScheme: colorScheme)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func didTap(_ number: Int) {
        if editMode == .overwrite {
            value = number
            editMode = .append
        } else {
            value = value * 10 + number
        }
    }

    
    @ViewBuilder
    private var backspaceButton: some View {
        Button {
            lightImpact.impactOccurred()
            backspaceTapped()
        } label: {
            Image(systemName: "delete.backward")
                .font(.system(size: 30, weight: .regular))
                .styledNumberPadText(height: 60, colorScheme: colorScheme)
        }
        .buttonStyle(PlainButtonStyle())
    }


    private func backspaceTapped() {
        value = value / 10
    }

    @ViewBuilder
    private var nextButton: some View {
        Button {
            lightImpact.impactOccurred()
            self.nextAction?()
        } label: {
            Text("Next")
                .font(.system(size: 30, weight: .medium))
                .styledNumberPadText(height: 60, colorScheme: colorScheme)

        }
        .buttonStyle(PlainButtonStyle())
    }
    
    
    @ViewBuilder
    private var completeSetButton: some View {
        Button {
            lightImpact.impactOccurred()
            self.nextAction?()
        } label: {
            Image(systemName: "checkmark.rectangle")
                .font(.system(size: 30, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor)
                        .shadow(radius: 0.4)
                )
                .foregroundColor(.white)
        }
        .buttonStyle(PlainButtonStyle())
    }

    func onNext(perform action: @escaping () -> Void) -> some View {
        var view = self
        view.nextAction = action
        return view
    }

}

private extension View {
    func styledNumberPadText(height: CGFloat, colorScheme: ColorScheme) -> some View {
        return self
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(colorScheme == .dark ? Color(.systemGray2) : Color(.white))
                    .shadow(radius: 0.4)
            )
            .foregroundColor(.primary)
    }
}
