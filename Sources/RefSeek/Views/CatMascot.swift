import SwiftUI

/// Reusable cat mascot view that loads the transparent cat image
struct CatMascot: View {
    var size: CGFloat = 48
    var rounded: Bool = false

    var body: some View {
        if let url = Bundle.module.url(forResource: rounded ? "AppIcon" : "CatMascot",
                                        withExtension: "png", subdirectory: "Resources"),
           let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: rounded ? size * 0.22 : 0))
        } else {
            Image(systemName: "cat.fill")
                .font(.system(size: size * 0.6))
                .foregroundStyle(.secondary)
        }
    }
}
