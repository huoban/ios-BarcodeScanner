import UIKit
import SwiftUI

final class ZoomScrollView: UIScrollView {
    let contentImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        minimumZoomScale = 1
        maximumZoomScale = 5
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentImageView.contentMode = .scaleAspectFit
        contentImageView.isUserInteractionEnabled = true
        addSubview(contentImageView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if zoomScale == 1 {
            contentImageView.frame = bounds
            contentSize = bounds.size
        }
    }
}

struct ZoomableImageView: UIViewRepresentable {
    let path: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ZoomScrollView {
        let scrollView = ZoomScrollView()
        scrollView.delegate = context.coordinator
        context.coordinator.scrollView = scrollView
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped(_:)))
        tap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(tap)
        return scrollView
    }

    func updateUIView(_ uiView: ZoomScrollView, context: Context) {
        guard context.coordinator.loadedPath != path else { return }
        context.coordinator.loadedPath = path
        uiView.contentImageView.image = ImageStore.portraitImage(at: path)
        uiView.setZoomScale(1, animated: false)
        uiView.setNeedsLayout()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: ZoomScrollView?
        var loadedPath: String?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? ZoomScrollView)?.contentImageView
        }

        @objc func doubleTapped(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView = scrollView else { return }
            if scrollView.zoomScale > 1 {
                scrollView.setZoomScale(1, animated: true)
            } else {
                let point = recognizer.location(in: scrollView.contentImageView)
                let size = CGSize(width: scrollView.bounds.width / 2.5, height: scrollView.bounds.height / 2.5)
                let origin = CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
                scrollView.zoom(to: CGRect(origin: origin, size: size), animated: true)
            }
        }
    }
}
