//
//  VideoPlayerView.swift
//  VideoLoader
//
//  Created by Khanh Anh Kiet on 2026-06-29.
//

import UIKit
import AVFoundation

final class VideoPlayerView: UIView {

    override class var layerClass: AnyClass {
        AVSampleBufferDisplayLayer.self
    }

    var displayLayer: AVSampleBufferDisplayLayer {
        layer as! AVSampleBufferDisplayLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        displayLayer.videoGravity = .resizeAspect
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        displayLayer.videoGravity = .resizeAspect
        backgroundColor = .black
    }

    /// Áp orientation của track (đã mất khi decode thủ công) bằng cách xoay layer.
    /// Chỉ lấy phần góc xoay từ preferredTransform để xoay quanh tâm.
    func applyPreferredTransform(_ transform: CGAffineTransform) {
        let angle = atan2(transform.b, transform.a)
        displayLayer.setAffineTransform(CGAffineTransform(rotationAngle: angle))
    }
}
