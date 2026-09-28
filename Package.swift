// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HeroesJourney",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HeroDomain", targets: ["HeroDomain"]),
        .library(name: "HeroContent", targets: ["HeroContent"]),
    ],
    targets: [
        // Pure domain: no UIKit, SwiftUI, HealthKit or file IO. Foundation only.
        .target(name: "HeroDomain"),
        // Versioned content bundle + sprite manifests + design tokens. Foundation only.
        .target(name: "HeroContent", dependencies: ["HeroDomain"]),
        .testTarget(name: "HeroDomainTests", dependencies: ["HeroDomain"]),
        .testTarget(name: "HeroContentTests", dependencies: ["HeroContent", "HeroDomain"]),
    ]
)
