//
//  VideoLoader.swift
//  VideoLoader
//
//  Created by Khanh Anh Kiet on 2026-06-22.
//

import AVFoundation

protocol Loader {
    func load(from url: URL) async throws -> (AVAsset, AVAssetTrack, AVAssetTrack?)
}

enum VideoLoaderError: Error{
    case cantLoad
}

nonisolated final class LoaderImpl: Loader, @unchecked Sendable {
    func load(from url: URL) async throws -> (AVAsset, AVAssetTrack, AVAssetTrack?) {
        let asset = AVURLAsset(url: url)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            print("[ERROR]: loading failed")
            throw VideoLoaderError.cantLoad
        }
        let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first
                
        return (asset, videoTrack, audioTrack)
    }
}
