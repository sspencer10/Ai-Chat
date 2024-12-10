//
//  TypingIndicator.swift
//  Chat with Ai Plus
//
//  Created by Steven Spencer on 11/27/24.
//
import SwiftUI
import Foundation
// Typing indicator view for assistant typing animation
struct TypingIndicatorView: View {
    @State private var animate = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.gray)
                .frame(width: 8, height: 8)
                .scaleEffect(animate ? 1 : 0.5)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: animate)
            
            Circle()
                .fill(Color.gray)
                .frame(width: 8, height: 8)
                .scaleEffect(animate ? 1 : 0.5)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.2), value: animate)
            
            Circle()
                .fill(Color.gray)
                .frame(width: 8, height: 8)
                .scaleEffect(animate ? 1 : 0.5)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.4), value: animate)
        }
        .onAppear {
            animate = true
        }
        .padding(.bottom, 10)
    }
}
