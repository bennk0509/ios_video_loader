//
//  VideoLoader.swift
//  VideoLoader
//
//  Created by Khanh Anh Kiet on 2026-06-22.
//

import AVFoundation

protocol VideoLoader {
    func load(from url: URL) async throws -> (AVAsset, AVAssetTrack)
}

enum VideoLoaderError: Error{
    case cantLoad
}

nonisolated final class AVVideoLoaderImpl: VideoLoader, @unchecked Sendable {
    func load(from url: URL) async throws -> (AVAsset, AVAssetTrack) {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            print("[ERROR]: loading failed")
            throw VideoLoaderError.cantLoad
        }
        return (asset, track)
    }
}
