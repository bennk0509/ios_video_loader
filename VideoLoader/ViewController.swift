//
//  ViewController.swift
//  VideoLoader
//
//  Created by Khanh Anh Kiet on 2026-06-18.
//

import UIKit
import CoreMedia
import VideoToolbox
import AVFoundation

class ViewController: UIViewController {

    private let loader: VideoLoader = AVVideoLoaderImpl()
    private var session: VTDecompressionSession?
    private let videoDisplayLayer = AVSampleBufferDisplayLayer()
    private let decoder: VideoDecode = VTVideoDecodeImpl()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupVideoDisplayLayer()
        Task {
            await runPipeline()
        }
    }
    private func setupVideoDisplayLayer() {
        videoDisplayLayer.frame = self.view.bounds
        videoDisplayLayer.videoGravity = .resizeAspect
        self.view.layer.addSublayer(videoDisplayLayer)
    }

    private func runPipeline() async {
        guard let url = Bundle.main.url(forResource: "video", withExtension: "mov") else {
            print("[ERROR] video.mov not found in bundle")
            return
        }

        do {
            let (asset, track) = try await loader.load(from: url)
            let reader = try AVVideoReaderImpl(asset: asset, track: track)
            
            var lastPTS: CMTime = .zero

            for await sample in reader.makeVideoSampleStream() {
                let sampleBuffer = sample.videoSampleBuffer
                
                let currentPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                if lastPTS != .zero {
                    let frameDuration = CMTimeGetSeconds(currentPTS) - CMTimeGetSeconds(lastPTS)
                    if frameDuration > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(frameDuration * 1_000_000_000))
                    }
                }
                lastPTS = currentPTS
                if let (pixelBuffer, pts) = try await decoder.decode(sample: sampleBuffer) {
                    self.enqueuePixelBufferToLayer(pixelBuffer, pts: pts)
                } else {
                    print("[PIPELINE WARNING] Skip configuration FRAME.")
                }
            }

        } catch {
            print("[ERROR]:", error)
        }
    }
    
    private func investigateVTDecompressionSession(sample: CMSampleBuffer){
        guard let formatDescription = CMSampleBufferGetFormatDescription(sample) else {
            print("[Decoder ERROR] Cannot see Format Description")
            return
        }
        
        if (session == nil){
            guard let formatDescription = CMSampleBufferGetFormatDescription(sample) else {
                print("[Decoder ERROR] Cant not see Format Description")
                return
            }
            
            let imageBufferAttributes: [CFString: Any] = [
                    kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                    kCVPixelBufferIOSurfacePropertiesKey: [:] as [CFString: Any]
                ]
            
            let status = VTDecompressionSessionCreate(allocator: nil, formatDescription: formatDescription, decoderSpecification: nil, imageBufferAttributes: imageBufferAttributes as CFDictionary, decompressionSessionOut: &session)
            
            if status != noErr {
                print("[Decoder ERROR] Failed to create session: \(status)")
                return
            }
        }
        guard let session = session else {return}
        VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sample,
            flags: [._EnableAsynchronousDecompression],
            infoFlagsOut: nil
        ) { [weak self] status, infoFlags, imageBuffer, pts, duration in
            
            if status == noErr, let pixelBuffer = imageBuffer {
                self?.enqueuePixelBufferToLayer(pixelBuffer, pts: pts)
            } else if status != noErr {
                print("[Decoder ERROR] Decodec Error in PTS \(CMTimeGetSeconds(pts)): \(status)")
            }
        }
    }
    private func enqueuePixelBufferToLayer(_ pixelBuffer: CVPixelBuffer, pts: CMTime) {
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
        
        // Đẩy vào luồng hiển thị trên Main Thread
        if let displayBuffer = displaySampleBuffer {
            DispatchQueue.main.async {
                if self.videoDisplayLayer.isReadyForMoreMediaData {
                    self.videoDisplayLayer.enqueue(displayBuffer)
                }
            }
        }
    }
}
