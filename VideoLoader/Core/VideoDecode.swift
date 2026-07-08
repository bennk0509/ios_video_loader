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
                        // Truyền lại thẻ màu (HLG/BT.2020...) từ format description gốc,
                        // nếu không display layer sẽ hiểu nhầm HDR như SDR → ảnh bị sáng/bạc màu.
                        self.transferColorAttachments(from: formatDescription, to: pixelBuffer)
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
    
    /// Copy các thẻ màu từ format description của track sang pixel buffer đã decode,
    /// để CMSampleBuffer bọc lại giữ đúng thông tin màu cho display layer.
    private func transferColorAttachments(from formatDescription: CMFormatDescription, to pixelBuffer: CVPixelBuffer) {
        let mappings: [(CFString, CFString)] = [
            (kCMFormatDescriptionExtension_ColorPrimaries, kCVImageBufferColorPrimariesKey),
            (kCMFormatDescriptionExtension_TransferFunction, kCVImageBufferTransferFunctionKey),
            (kCMFormatDescriptionExtension_YCbCrMatrix, kCVImageBufferYCbCrMatrixKey)
        ]
        for (extensionKey, bufferKey) in mappings {
            if let value = CMFormatDescriptionGetExtension(formatDescription, extensionKey: extensionKey) {
                CVBufferSetAttachment(pixelBuffer, bufferKey, value, .shouldPropagate)
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
