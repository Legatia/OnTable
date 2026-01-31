import SwiftUI
import UIKit

class ShareService {
    static let shared = ShareService()

    private init() {}

    // MARK: - Generate Share Card Image

    @MainActor
    func generateCardImage(
        decision: Decision,
        isPremium: Bool,
        template: ShareCardView.CardTemplate
    ) -> UIImage? {
        let cardView = ShareCardView(
            decision: decision,
            isPremium: isPremium,
            template: template
        )

        // Use ImageRenderer for iOS 16+
        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: cardView)
            renderer.scale = UIScreen.main.scale
            return renderer.uiImage
        } else {
            // Fallback for iOS 15
            return renderViewToImage(cardView)
        }
    }

    // MARK: - iOS 15 Fallback Rendering

    @MainActor
    private func renderViewToImage<V: View>(_ view: V) -> UIImage? {
        let controller = UIHostingController(rootView: view)
        let targetSize = CGSize(width: 400, height: 400)

        controller.view.bounds = CGRect(origin: .zero, size: targetSize)
        controller.view.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    // MARK: - Share Image

    @MainActor
    func shareImage(_ image: UIImage, from viewController: UIViewController? = nil) {
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        // Get the presenting view controller
        let presenter = viewController ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController

        // iPad requires popover configuration
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter?.view
            popover.sourceRect = CGRect(
                x: UIScreen.main.bounds.midX,
                y: UIScreen.main.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        presenter?.present(activityVC, animated: true)
    }

    // MARK: - Convenience Method

    @MainActor
    func shareDecision(
        _ decision: Decision,
        isPremium: Bool,
        template: ShareCardView.CardTemplate
    ) {
        guard let image = generateCardImage(
            decision: decision,
            isPremium: isPremium,
            template: template
        ) else {
            print("Failed to generate share card image")
            return
        }

        shareImage(image)
    }
}
