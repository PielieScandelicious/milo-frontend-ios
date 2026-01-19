//
//  DonutChartView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI

struct DonutChartView: View {
    let title: String
    let subtitle: String
    let totalAmount: Double
    let segments: [ChartSegment]
    let size: CGFloat
    
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: size * 0.15)
                    .frame(width: size, height: size)
                
                // Segments
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    DonutSegment(
                        startAngle: segment.startAngle,
                        endAngle: segment.endAngle,
                        color: segment.color,
                        lineWidth: size * 0.15,
                        animationProgress: animationProgress
                    )
                    .frame(width: size, height: size)
                }
                
                // Center content
                VStack(spacing: 4) {
                    if subtitle == "visits" {
                        Text(String(format: "%.0f", totalAmount))
                            .font(.system(size: size * 0.16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    } else {
                        Text(String(format: "€%.0f", totalAmount))
                            .font(.system(size: size * 0.16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: size * 0.09, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
    }
}

struct DonutSegment: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    let lineWidth: CGFloat
    let animationProgress: CGFloat
    
    var body: some View {
        let startFraction = startAngle.degrees / 360.0
        let endFraction = endAngle.degrees / 360.0
        let animatedEndFraction = startFraction + (endFraction - startFraction) * animationProgress
        
        Circle()
            .trim(from: startFraction, to: animatedEndFraction)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}

struct ChartSegment: Identifiable {
    let id = UUID()
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    let value: Double
    let label: String
    let percentage: Int
}

// MARK: - Helper to create segments from data
extension Array where Element == Category {
    func toChartSegments() -> [ChartSegment] {
        var currentAngle: Double = 0
        let colors: [Color] = [
            Color(red: 0.3, green: 0.7, blue: 1.0),   // Blue
            Color(red: 0.4, green: 0.8, blue: 0.5),   // Green
            Color(red: 1.0, green: 0.7, blue: 0.3),   // Orange
            Color(red: 0.9, green: 0.4, blue: 0.6),   // Pink
            Color(red: 0.7, green: 0.5, blue: 1.0),   // Purple
            Color(red: 0.3, green: 0.9, blue: 0.9),   // Cyan
            Color(red: 1.0, green: 0.6, blue: 0.4),   // Coral
            Color(red: 0.6, green: 0.9, blue: 0.4),   // Lime
        ]
        
        return enumerated().map { index, category in
            let percentage = Double(category.percentage) / 100.0
            let angleRange = 360.0 * percentage
            let segment = ChartSegment(
                startAngle: .degrees(currentAngle),
                endAngle: .degrees(currentAngle + angleRange),
                color: colors[index % colors.count],
                value: category.spent,
                label: category.name,
                percentage: category.percentage
            )
            currentAngle += angleRange
            return segment
        }
    }
}
