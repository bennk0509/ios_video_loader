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
}
