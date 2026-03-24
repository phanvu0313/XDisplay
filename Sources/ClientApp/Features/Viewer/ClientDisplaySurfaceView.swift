import SwiftUI
import AVFoundation
import UIKit

struct ClientDisplaySurfaceView: View {
    let renderer: RemoteDisplayRenderer
    let mockFrame: MockFrameDescriptor?
    let statusText: String
    let scaleMode: ClientDisplayScaleMode

    var body: some View {
        ZStack {
            Color.black

            ClientStreamingVideoSurface(renderer: renderer)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)

            if let mockFrame {
                Canvas { context, size in
                    let background = Path(CGRect(origin: .zero, size: size))
                    context.fill(background, with: .linearGradient(
                        Gradient(colors: [
                            Color(hue: mockFrame.accentHue, saturation: 0.8, brightness: 0.95),
                            Color.black
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: size.height)
                    ))

                    let columns = 10
                    let spacing = size.width / CGFloat(columns)
                    for index in 0..<columns {
                        let normalized = Double(index) / Double(columns)
                        let wave = sin(mockFrame.phase + normalized * .pi * 2)
                        let height = max(30, size.height * CGFloat(0.25 + ((wave + 1) * 0.3)))
                        let x = CGFloat(index) * spacing + spacing * 0.15
                        let rect = CGRect(
                            x: x,
                            y: size.height - height - 24,
                            width: spacing * 0.7,
                            height: height
                        )

                        let path = RoundedRectangle(cornerRadius: 18).path(in: rect)
                        let color = Color(
                            hue: (mockFrame.accentHue + normalized * 0.22).truncatingRemainder(dividingBy: 1),
                            saturation: 0.7,
                            brightness: 0.95
                        )
                        context.fill(path, with: .color(color))
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct ClientStreamingVideoSurface: UIViewRepresentable {
    let renderer: RemoteDisplayRenderer

    @MainActor
    func makeUIView(context: Context) -> ClientVideoViewport {
        let viewport = ClientVideoViewport()

        renderer.setVideoFrameSink { [weak viewport] decodedFrame, frame in
            viewport?.updateFrame(decodedFrame, frame: frame)
        }

        return viewport
    }

    @MainActor
    func updateUIView(_ viewport: ClientVideoViewport, context _: Context) {
        renderer.setVideoFrameSink { decodedFrame, frame in
            viewport.updateFrame(decodedFrame, frame: frame)
        }
    }

    @MainActor
    static func dismantleUIView(_ viewport: ClientVideoViewport, coordinator _: ()) {
        viewport.clearImage()
    }
}

final class ClientVideoViewport: UIView {
    private let sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
    private let imageView = UIImageView()
    private var currentAspectRatio: CGFloat = 16.0 / 9.0

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .black
        clipsToBounds = true
        isOpaque = true

        sampleBufferDisplayLayer.videoGravity = .resize
        sampleBufferDisplayLayer.backgroundColor = UIColor.black.cgColor
        layer.addSublayer(sampleBufferDisplayLayer)

        imageView.backgroundColor = .black
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleToFill
        imageView.isOpaque = true
        addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutVideoFrame()
    }

    func updateFrame(_ decodedFrame: RemoteDisplayRenderer.DecodedVideoFrame, frame: EncodedVideoFrame) {
        imageView.accessibilityLabel = "Remote display preview \(frame.width) by \(frame.height)"
        currentAspectRatio = max(CGFloat(frame.width) / max(CGFloat(frame.height), 1), 0.1)

        switch decodedFrame.storage {
        case let .image(image):
            if sampleBufferDisplayLayer.isReadyForMoreMediaData {
                sampleBufferDisplayLayer.flushAndRemoveImage()
            }
            imageView.isHidden = false
            imageView.image = image
        case let .sampleBuffer(decodedSampleBuffer):
            imageView.isHidden = true
            imageView.image = nil
            if sampleBufferDisplayLayer.status == .failed {
                sampleBufferDisplayLayer.flush()
            }
            sampleBufferDisplayLayer.enqueue(decodedSampleBuffer.sampleBuffer)
        }

        setNeedsLayout()
    }

    func clearImage() {
        imageView.image = nil
        imageView.isHidden = false
        sampleBufferDisplayLayer.flushAndRemoveImage()
    }

    private func layoutVideoFrame() {
        guard bounds.width > 0, bounds.height > 0 else {
            imageView.frame = bounds
            sampleBufferDisplayLayer.frame = bounds
            return
        }

        let isLandscapeViewport = bounds.width > bounds.height
        let targetSize: CGSize

        if isLandscapeViewport {
            let height = bounds.height
            let width = height * currentAspectRatio
            targetSize = CGSize(width: width, height: height)
        } else {
            let width = bounds.width
            let height = width / currentAspectRatio
            targetSize = CGSize(width: width, height: height)
        }

        let frame = CGRect(
            x: (bounds.width - targetSize.width) / 2,
            y: (bounds.height - targetSize.height) / 2,
            width: targetSize.width,
            height: targetSize.height
        ).integral
        imageView.frame = frame
        sampleBufferDisplayLayer.frame = frame
    }
}
