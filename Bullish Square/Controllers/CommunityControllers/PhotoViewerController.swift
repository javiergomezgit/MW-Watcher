//
//  PhotoViewerController.swift
//  Bullish Square
//

import UIKit

///A post's photos full screen and uncropped: swipe between them, pinch or double-tap to zoom,
///close with the button or by swiping down. The feed's card only shows a cropped preview.
///(BS-267)
final class PhotoViewerController: UIViewController, UIScrollViewDelegate {

    // MARK: - Properties

    private let urls: [String]
    private let startIndex: Int
    private let pager = UIScrollView()
    private let counterLabel = UILabel()
    private var pages: [UIScrollView] = []

    init(urls: [String], startIndex: Int) {
        self.urls = urls
        self.startIndex = min(max(0, startIndex), max(0, urls.count - 1))
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var prefersStatusBarHidden: Bool { true }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        pager.isPagingEnabled = true
        pager.showsHorizontalScrollIndicator = false
        pager.delegate = self
        pager.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pager)

        for url in urls {
            let page = UIScrollView()
            page.minimumZoomScale = 1
            page.maximumZoomScale = 4
            page.showsVerticalScrollIndicator = false
            page.showsHorizontalScrollIndicator = false
            page.delegate = self
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.image = RemoteImageCache.shared.cached(url)
            page.addSubview(imageView)
            if imageView.image == nil {
                RemoteImageCache.shared.load(url) { [weak imageView] image in imageView?.image = image }
            }
            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
            doubleTap.numberOfTapsRequired = 2
            page.addGestureRecognizer(doubleTap)
            pager.addSubview(page)
            pages.append(page)
        }

        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)), for: .normal)
        close.tintColor = .white
        close.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        close.layer.cornerRadius = 20
        close.accessibilityLabel = "Close"
        close.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)

        counterLabel.font = UIFont(name: "Avenir-Heavy", size: 15) ?? .boldSystemFont(ofSize: 15)
        counterLabel.textColor = .white
        counterLabel.isHidden = urls.count < 2

        for subview in [close, counterLabel] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        NSLayoutConstraint.activate([
            pager.topAnchor.constraint(equalTo: view.topAnchor),
            pager.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            pager.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pager.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            close.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            close.widthAnchor.constraint(equalToConstant: 40),
            close.heightAnchor.constraint(equalToConstant: 40),
            counterLabel.centerYAnchor.constraint(equalTo: close.centerYAnchor),
            counterLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(swipedDown))
        swipeDown.direction = .down
        view.addGestureRecognizer(swipeDown)
    }

    ///Pages are laid out by frame, each the size of the screen; the first layout also jumps
    ///to the photo that was tapped.
    private var didScrollToStart = false

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = pager.bounds.size
        guard size.width > 0 else { return }
        for (index, page) in pages.enumerated() {
            page.frame = CGRect(x: CGFloat(index) * size.width, y: 0, width: size.width, height: size.height)
            page.zoomScale = 1
            page.contentSize = size
            page.subviews.first?.frame = CGRect(origin: .zero, size: size)
        }
        pager.contentSize = CGSize(width: size.width * CGFloat(pages.count), height: size.height)
        if !didScrollToStart {
            didScrollToStart = true
            pager.contentOffset = CGPoint(x: CGFloat(startIndex) * size.width, y: 0)
        }
        updateCounter()
    }

    // MARK: - Zoom and paging

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        scrollView === pager ? nil : scrollView.subviews.first
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === pager { updateCounter() }
    }

    private func updateCounter() {
        let width = max(1, pager.bounds.width)
        let index = Int((pager.contentOffset.x / width).rounded())
        counterLabel.text = "\(min(index, urls.count - 1) + 1) / \(urls.count)"
    }

    @objc private func doubleTapped(_ recognizer: UITapGestureRecognizer) {
        guard let page = recognizer.view as? UIScrollView else { return }
        if page.zoomScale > 1 {
            page.setZoomScale(1, animated: true)
        } else {
            let point = recognizer.location(in: page.subviews.first)
            let size = CGSize(width: page.bounds.width / 2.5, height: page.bounds.height / 2.5)
            page.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                                 width: size.width, height: size.height), animated: true)
        }
    }

    ///Only when not zoomed in, so a swipe inside a zoomed photo pans it instead.
    @objc private func swipedDown() {
        let width = max(1, pager.bounds.width)
        let index = Int((pager.contentOffset.x / width).rounded())
        guard index < pages.count, pages[index].zoomScale <= 1 else { return }
        dismiss(animated: true)
    }
}
