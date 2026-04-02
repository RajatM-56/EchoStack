//
//  UIComponents.swift
//  EchoStack
//
//  Created by GEU on 02/04/26.
//

import SwiftUI


struct BookFolderView: View {
    let title: String
    let itemCount: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 110, height: 155)
                
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 3, height: 155)
                    .offset(x: 10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    Text("\(itemCount) items")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.leading, 20)
                .padding(.vertical, 18)
            }
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 4, y: 6)
        }
    }
}


struct ContinueCard: View {
    let fileName: String
    let inkColor: Color
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 55, height: 55)
                
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.premiumGold)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("CONTINUE READING")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.premiumGold)
                    .kerning(1)
                
                Text(fileName)
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(inkColor)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "arrow.right.circle.fill")
                .font(.title2)
                .foregroundStyle(.premiumGold.opacity(0.4))
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.premiumGold, lineWidth: 1.5)
            }
            .shadow(color: Color.black.opacity(0.05), radius: 10)
        )
    }
}


struct SpeakButtonUI: View {
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 64, height: 64)
                    .shadow(radius: 5)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.premiumGold)
            }
            Text("Speak")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.secondary)
        }
    }
}


struct FloatingAddButton: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 60, height: 60)
                .shadow(radius: 5)
            
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundColor(.brown)
        }
    }
}


extension ShapeStyle where Self == LinearGradient {
    static var premiumGold: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.75, green: 0.58, blue: 0.18),
                Color(red: 1.0, green: 0.86, blue: 0.53)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
