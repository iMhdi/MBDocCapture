//
//  Glass.swift
//  MBDocCapture
//
//  Copyright © 2019-2026 El Mahdi Boukhris <m.boukhris@gmail.com>. MIT License.
//

import UIKit

/// Builds floating controls: Liquid Glass on iOS 26+, material blur before (or when glass is turned off).
enum Glass {

    static func usesGlass(_ appearance: MBDocCaptureConfiguration.Appearance) -> Bool {
        guard appearance.usesLiquidGlass else { return false }
        #if compiler(>=6.2) // iOS 26 SDK (Xcode 26+); older toolchains always use the fallback.
        if #available(iOS 26.0, *) { return true }
        #endif
        return false
    }

    /// A glass background view, capsule shaped unless `cornerRadius` is given. Put content in `contentView`.
    static func background(_ appearance: MBDocCaptureConfiguration.Appearance, cornerRadius: CGFloat? = nil, interactive: Bool = false) -> UIVisualEffectView {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), usesGlass(appearance) {
            let effect = UIGlassEffect()
            effect.isInteractive = interactive
            let view = UIVisualEffectView(effect: effect)
            view.cornerConfiguration = cornerRadius.map { .uniformCorners(radius: .fixed($0)) } ?? .capsule()
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }
        #endif
        let view = RoundedEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        view.fixedCornerRadius = cornerRadius
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    /// A capsule button with an SF Symbol and optional title.
    static func button(image: UIImage?, title: String? = nil, appearance: MBDocCaptureConfiguration.Appearance) -> UIButton {
        let button = UIButton(configuration: configuration(image: image, title: title, isActive: false, appearance: appearance))
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    /// Button configuration; `isActive` renders the accent-tinted variant (e.g. flashlight on).
    static func configuration(image: UIImage?, title: String?, isActive: Bool, appearance: MBDocCaptureConfiguration.Appearance) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.background.visualEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        configuration.background.backgroundColor = isActive ? appearance.tintColor.withAlphaComponent(0.85) : .clear
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), usesGlass(appearance) {
            configuration = isActive ? .prominentGlass() : .glass()
            configuration.baseBackgroundColor = isActive ? appearance.tintColor : nil
        }
        #endif
        configuration.cornerStyle = .capsule
        // Glass adapts its content color to what is behind it; pin icons to the configured color like the title.
        let foreground = isActive ? UIColor.black : appearance.controlForegroundColor
        configuration.image = image?.withTintColor(foreground, renderingMode: .alwaysOriginal)
        configuration.title = title
        configuration.imagePadding = 6
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .body, scale: .medium)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: title == nil ? 12 : 16)
        configuration.baseForegroundColor = foreground
        return configuration
    }
}

/// Material view that keeps a capsule (or fixed radius) shape whatever its size (pre-iOS 26 fallback).
private final class RoundedEffectView: UIVisualEffectView {
    var fixedCornerRadius: CGFloat?

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = fixedCornerRadius ?? min(bounds.width, bounds.height) / 2
        layer.cornerCurve = .continuous
        clipsToBounds = true
    }
}
