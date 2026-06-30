//
//  VideoReader.swift
//  VideoLoader
//
//  Created by Khanh Anh Kiet on 2026-06-18.
//

import AVFoundation

protocol VideoReader{
    func makeVideoSampleStream() -> AsyncStream<VideoSample>
}

enum ReaderError: Error{
    case cantAddOutput
    case failedToStartReading
}

nonisolated final class AVVideoReaderImpl: VideoReader, @unchecked Sendable{
    private let reader: AVAssetReader
    private let output: AVAssetReaderTrackOutput
    
    init(asset: AVAsset, track: AVAssetTrack) throws {
        self.reader = try AVAssetReader(asset: asset)
        self.output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        guard reader.canAdd(output) else{
            throw ReaderError.cantAddOutput
        }
        reader.add(output)
    }
    
    //GOAL We need to run while loop in background
    func makeVideoSampleStream() -> AsyncStream<VideoSample> {
        return AsyncStream{ continuation in
            let task = Task.detached(priority: .userInitiated){
                guard self.reader.startReading() else{
                    print("[ERROR] can't start reading: \(String(describing: self.reader.error))")
                    continuation.finish()
                    return
                }
                while let sampleBuffer = self.output.copyNextSampleBuffer(){
                    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    let isKeyFrame = self.isKeyFrame(sampleBuffer: sampleBuffer)
                    
                    let sample = VideoSample(videoSampleBuffer: sampleBuffer, presentationTimeStamp: pts, isKeyFrame: isKeyFrame)
                    continuation.yield(sample)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
                self.reader.cancelReading()
            }
        }
    }
    
    //check is it keyframe or not
    private func isKeyFrame(sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]] else {
            return false
        }
        if attachments.isEmpty {
            return true
        }
        for attachment in attachments {
            if let notSync = attachment[kCMSampleAttachmentKey_NotSync] as? NSNumber, notSync.boolValue {
                return false
            }
        }
        return true
    }
}
