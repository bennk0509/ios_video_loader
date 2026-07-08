//
//  AudioReader.swift
//  VideoLoader
//
//  Created by Khanh Anh Kiet on 2026-07-06.
//

import AVFoundation



protocol AudioReader{
    
}

nonisolated final class AVAudioReaderImpl: AudioReader, @unchecked Sendable{
    
    private let reader: AVAssetReader
    private let output: AVAssetReaderTrackOutput
    
    init(asset: AVAsset, track: AVAssetTrack) throws {
        self.reader = try AVAssetReader(asset: asset)
//        let audioOutputSettings: [String: Any] = [
//            AVFormatIDKey: kAudioFormatLinearPCM,
//            AVLinearPCMBitDepthKey: 16,
//            AVLinearPCMIsFloatKey: false,
//            AVLinearPCMIsBigEndianKey: false,
//            AVLinearPCMIsNonInterleaved: false
//        ]
        self.output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        guard reader.canAdd(output) else {
            throw ReaderError.cantAddOutput
        }
        reader.add(output)
                
    }
    
    func makeAudioSampleStream() -> AsyncStream<AudioSample> {
        return AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                guard self.reader.startReading() else {
                    print("[ERROR] Audio reader can't start reading: \(String(describing: self.reader.error))")
                    continuation.finish()
                    return
                }
                
                while let sampleBuffer = self.output.copyNextSampleBuffer() {
                    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    
                    let sample = AudioSample(audioSampleBuffer: sampleBuffer, presentationTimeStamp: pts)
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
}
