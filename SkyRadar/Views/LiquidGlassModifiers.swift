//
//  LiquidGlassModifiers.swift
//  SkyRadar
//
//  Стеклянные поверхности Liquid Glass: материал, блик, обводка и свечение статуса.
//

import SwiftUI

/// Стеклянная пластина с преломлением, бликом и световой кромкой.
struct LiquidGlassPlate: View {
    var tint: Color
    var cornerRadius: CGFloat = 28
    var material: Material = .ultraThinMaterial
    var glows: Bool = true
    var animatesSheen: Bool = false
    var isPulsing: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(material)
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.28),
                            tint.opacity(0.06),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            .overlay(alignment: .top) {
                shape.fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.white.opacity(0.02), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(maxHeight: .infinity, alignment: .top)
                .mask(
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
            }
            .overlay {
                SpecularHighlightBorder(cornerRadius: cornerRadius, tint: tint)
            }
            .overlay {
                if animatesSheen {
                    GlassSheen(cornerRadius: cornerRadius)
                }
            }
            .shadow(
                color: glows ? tint.opacity(isPulsing ? 0.55 : 0.24) : .clear,
                radius: glows ? (isPulsing ? 22 : 14) : 0,
                y: glows ? 8 : 0
            )
            .allowsHitTesting(false)
    }
}

/// Тонкая световая кромка: яркий блик сверху-слева к полупрозрачному краю.
struct SpecularHighlightBorder: View {
    var cornerRadius: CGFloat
    var tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.92),
                        tint.opacity(0.55),
                        Color.white.opacity(0.14),
                        tint.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

/// Медленный световой перелив по стеклу.
struct GlassSheen: View {
    var cornerRadius: CGFloat
    @State private var slides = false

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    Color.white.opacity(0.0),
                    Color.white.opacity(0.28),
                    Color.white.opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: max(geo.size.width * 0.42, 36))
            .rotationEffect(.degrees(22))
            .offset(x: slides ? geo.size.width * 0.9 : -geo.size.width * 0.7)
            .onAppear {
                withAnimation(.linear(duration: 3.8).repeatForever(autoreverses: false)) {
                    slides = true
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
    }
}

/// Кладёт Liquid Glass под содержимое.
struct LiquidGlassModifier: ViewModifier {
    var tint: Color
    var cornerRadius: CGFloat
    var material: Material
    var glows: Bool
    var animatesSheen: Bool
    var isPulsing: Bool

    func body(content: Content) -> some View {
        content
            .background {
                LiquidGlassPlate(
                    tint: tint,
                    cornerRadius: cornerRadius,
                    material: material,
                    glows: glows,
                    animatesSheen: animatesSheen,
                    isPulsing: isPulsing
                )
            }
    }
}

extension View {
    /// Стеклянная подложка с акцентом уровня угрозы.
    func liquidGlass(
        tint: Color,
        cornerRadius: CGFloat = 28,
        material: Material = .ultraThinMaterial,
        glows: Bool = true,
        animatesSheen: Bool = false,
        isPulsing: Bool = false
    ) -> some View {
        modifier(
            LiquidGlassModifier(
                tint: tint,
                cornerRadius: cornerRadius,
                material: material,
                glows: glows,
                animatesSheen: animatesSheen,
                isPulsing: isPulsing
            )
        )
    }
}

/// Компактный бейдж статуса.
struct ThreatBadge: View {
    var level: ThreatLevel
    var prominent: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: level.symbolName)
                .font(prominent ? .title3.weight(.semibold) : .caption.weight(.bold))
                .symbolEffect(.bounce, value: level)
            Text(level.shortStatus)
                .font(prominent ? .headline : .caption.weight(.semibold))
        }
        .foregroundStyle(level.accent)
        .padding(.horizontal, prominent ? 14 : 10)
        .padding(.vertical, prominent ? 8 : 6)
        .liquidGlass(
            tint: level.accent,
            cornerRadius: 16,
            material: .thinMaterial,
            glows: true,
            animatesSheen: false,
            isPulsing: level == .danger
        )
    }
}

/// Капсула региона на стекле.
struct RegionChip: View {
    var title: String
    var tint: Color
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.caption.weight(.semibold))
                .symbolEffect(.bounce, value: isSelected)
            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(isSelected ? tint : Color.white.opacity(0.82))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .liquidGlass(
            tint: isSelected ? tint : Color.white.opacity(0.35),
            cornerRadius: 18,
            material: .thinMaterial,
            glows: isSelected,
            animatesSheen: false,
            isPulsing: false
        )
    }
}
