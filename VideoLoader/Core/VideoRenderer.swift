//
//  VideoRenderer.swift
//  VideoLoader
//
//  Created by Khanh Anh Kiet on 2026-06-29.
//

import AVFoundation

protocol VideoRenderer{
    // this function receive the CVPixelBuffer and pts from VideoDecode
    func render(pixelBuffer: CVPixelBuffer, pts: CMTime)
    func flush()
}

nonisolated final class VideoRendererImpl: VideoRenderer, @unchecked Sendable{
    private let videoDisplayLayer: AVSampleBufferDisplayLayer
    
    init(videoDisplayLayer: AVSampleBufferDisplayLayer) {
        self.videoDisplayLayer = videoDisplayLayer
    }
    
    func render(pixelBuffer: CVPixelBuffer, pts: CMTime) {
        var formatDescription: CMVideoFormatDescription?
        
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDescription)
        
        guard let formatDescription = formatDescription else { return }
        var timingInfo = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: pts, decodeTimeStamp: .invalid)
        
        var displaySampleBuffer: CMSampleBuffer?
        
        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleTiming: &timingInfo,
            sampleBufferOut: &displaySampleBuffer
        )
        
        guard let displaySampleBuffer else {return}
        
        DispatchQueue.main.async {
            if self.videoDisplayLayer.sampleBufferRenderer.isReadyForMoreMediaData {
                self.videoDisplayLayer.sampleBufferRenderer.enqueue(displaySampleBuffer)
            }
        }
    }
    func flush() {
        DispatchQueue.main.async {
            self.videoDisplayLayer.sampleBufferRenderer.flush()
        }
    }
}
