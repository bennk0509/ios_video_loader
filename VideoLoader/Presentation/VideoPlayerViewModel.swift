import Foundation

import AVFoundation

enum State{
    case idle
    case playing
    case stopped
    case paused
    case finished
    case failed(String)
}
@MainActor
final class VideoPlayerViewModel{
    private let url: URL
    private let loader: Loader
    private let decoder: VideoDecode
    private let mediaManager: MediaManager

    private var playbackTask: Task<Void,Never>?

    private(set) var state: State = .idle{
        didSet{ onStateChange?(state)}
    }
    var onStateChange: ((State) -> Void)?
    var onPreferredTransform: ((CGAffineTransform) -> Void)?

    init(url: URL, loader: Loader, decoder: VideoDecode, mediaManager: MediaManager) {
        self.url = url
        self.loader = loader
        self.decoder = decoder
        self.mediaManager = mediaManager
    }

    private func run() async{
        do{
            let (asset, videoTrack, audioTrack) = try await loader.load(from: url)
            let transform = try await videoTrack.load(.preferredTransform)
            onPreferredTransform?(transform)

            let videoReader = try AVVideoReaderImpl(asset: asset, track: videoTrack)
            mediaManager.prepare()
            if let audioTrack {
                let audioReader = try AVAudioReaderImpl(asset: asset, track: audioTrack)
                mediaManager.startAudio(from: audioReader.makeAudioSampleStream())
            }
            mediaManager.play()
            for await sample in videoReader.makeVideoSampleStream(){
                if Task.isCancelled {return}
                if let (pixelBuffer, pts) = try await decoder.decode(sample: sample.videoSampleBuffer) {
                    await mediaManager.enqueueVideo(pixelBuffer: pixelBuffer, pts: pts)
                }
            }
            mediaManager.finishVideo()
            state = .finished
        } catch{
            print("[VIEWMODEL ERROR]:", error)
            state = .failed("\(error)")
        }
    }

    func start(){
        play()
    }

    func stop(){
        playbackTask?.cancel()
        playbackTask = nil
        mediaManager.stop()
        state = .stopped
    }

    func pause(){
        guard case .playing = state else { return }
        mediaManager.pause()
        state = .paused
    }

    func resume(){
        guard case .paused = state else { return }
        mediaManager.resume()
        state = .playing
    }

    func play(){
        stop()
        state = .playing
        playbackTask = Task{ [weak self] in
            guard let self = self else {return}
            await self.run()
        }
    }

    func togglePlay(){
        switch state{
        case .playing: stop()
        default: play()
        }
    }


}
