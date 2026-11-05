import AVFoundation
import AVKit
import AppKit
import BuehneEngine
import SwiftUI

final class PlayerLayerView: NSView {
    let playerLayer = AVPlayerLayer()
    let frameLayer = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = playerLayer
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = NSColor.clear.cgColor
        frameLayer.contentsGravity = .resizeAspect
        frameLayer.isHidden = true
        playerLayer.addSublayer(frameLayer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer = playerLayer
    }

    override func layout() {
        super.layout()
        frameLayer.frame = bounds
    }

    func show(frame: CGImage?, metal: CALayer?) {
        if let metal {
            if metal.superlayer !== playerLayer {
                metal.frame = bounds
                metal.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
                playerLayer.addSublayer(metal)
            }
            metal.isHidden = false
            frameLayer.isHidden = true
            playerLayer.isHidden = false
            return
        }
        frameLayer.contents = frame
        frameLayer.isHidden = frame == nil
        playerLayer.isHidden = frame != nil
    }
}

struct VideoSurface: NSViewRepresentable {
    var player: AVPlayer
    var gravity: AVLayerVideoGravity
    var frame: RenderedFrame?
    var metalLayer: CALayer?
    var onLayer: (AVPlayerLayer) -> Void
    func makeNSView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = gravity
        view.show(frame: image(from: frame), metal: metalLayer)
        onLayer(view.playerLayer)
        return view
    }

    func updateNSView(_ view: PlayerLayerView, context: Context) {
        if view.playerLayer.player !== player { view.playerLayer.player = player }
        view.playerLayer.videoGravity = gravity
        view.show(frame: image(from: frame), metal: metalLayer)
        onLayer(view.playerLayer)
    }

    private func image(from frame: RenderedFrame?) -> CGImage? {
        guard let frame, frame.width > 0, frame.height > 0 else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let provider = CGDataProvider(data: frame.bgra as CFData)
        return CGImage(
            width: frame.width,
            height: frame.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: frame.width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
            provider: provider!,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}

@MainActor
final class PictureInPictureBridge {
    private var controller: AVPictureInPictureController?
    private weak var layer: AVPlayerLayer?

    func attach(_ layer: AVPlayerLayer) {
        guard self.layer !== layer else { return }
        self.layer = layer
        controller = AVPictureInPictureController(playerLayer: layer)
    }

    func toggle() -> String? {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            return "Picture in Picture is not supported"
        }
        guard let controller else { return "Picture in Picture is not ready" }
        if controller.isPictureInPictureActive {
            controller.stopPictureInPicture()
            return nil
        }
        guard controller.isPictureInPicturePossible else {
            return "Picture in Picture is not available for this window"
        }
        controller.startPictureInPicture()
        return nil
    }
}
