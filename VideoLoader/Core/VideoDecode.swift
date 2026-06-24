//
//  VideoDecodec.swift
//  VideoLoader
//
//  Created by Khanh Anh Kiet on 2026-06-22.
//

import VideoToolbox

protocol VideoDecode{
    func decode(sample: CMSampleBuffer) async throws -> (CVPixelBuffer, CMTime)?
}

enum VideoDecodeError: Error{
    case cantCreateDecode
    case cantFindFormatDescription
    case sessionNotReady
    case decodingFailed(OSStatus)
}

nonisolated final class VTVideoDecodeImpl: VideoDecode{
    private var session: VTDecompressionSession?
    
    init(){}
    
    func decode(sample: CMSampleBuffer) async throws -> (CVPixelBuffer, CMTime)? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sample) else {
            return nil
        }
        
        if session == nil{
            try setUpSession(with: formatDescription)
        }
        guard let session = session else {
            throw VideoDecodeError.sessionNotReady
        }
        return try await withCheckedThrowingContinuation { continuation in
            VTDecompressionSessionDecodeFrame(
                session,
                sampleBuffer: sample,
                flags: [._EnableAsynchronousDecompression],
                infoFlagsOut: nil
            ) { status, _, imageBuffer, pts, _ in
                
                if status == noErr {
                    if let pixelBuffer = imageBuffer {
                        continuation.resume(returning: (pixelBuffer, pts))
                    } else {
                        continuation.resume(returning: nil)
                    }
                } else {
                    continuation.resume(throwing: VideoDecodeError.decodingFailed(status))
                }
            }
        }
    }
    
    private func setUpSession(with formatDescription: CMVideoFormatDescription) throws{
        let imageBufferAttributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as [CFString: Any]
        ]
        
        let status = VTDecompressionSessionCreate(allocator: nil, formatDescription: formatDescription, decoderSpecification: nil, imageBufferAttributes: imageBufferAttributes as CFDictionary, decompressionSessionOut: &session)
        
        if status != noErr{
            print("[DECODE] Failed to create a session: \(status)")
            throw VideoDecodeError.cantCreateDecode
        }
    }
    
    deinit {
        if let session = session {
            VTDecompressionSessionInvalidate(session)
        }
    }
    
}
