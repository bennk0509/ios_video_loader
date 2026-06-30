import Foundation

import AVFoundation

enum State{
    case idle
    case playing
    case stopped
    case finished
    case failed(String)
}
@MainActor
final class VideoPlayerViewModel{
    private let url: URL
    private let loader: VideoLoader
    private let decoder: VideoDecode
    private let renderer: VideoRenderer
    private var playbackTask: Task<Void,Never>?
    
    private(set) var state: State = .idle{
        didSet{ onStateChange?(state)}
    }
    var onStateChange: ((State) -> Void)?
    
    init(url: URL, loader: VideoLoader, decoder: VideoDecode, renderer: VideoRenderer) {
        self.url = url
        self.loader = loader
        self.decoder = decoder
        self.renderer = renderer
    }
    
    private func run() async{
        do{
            let (asset, track) = try await loader.load(from: url)
            let reader = try AVVideoReaderImpl(asset: asset, track: track)
            for await sample in reader.makeVideoSampleStream(){
                if Task.isCancelled {return}
                let sampleBuffer = sample.videoSampleBuffer
                if let (pixelBuffer, pts) = try await decoder.decode(sample: sampleBuffer) {
                    renderer.render(pixelBuffer: pixelBuffer, pts: pts)
                }
            }
            state = .finished
        } catch{
            print("[VIEWMODEL ERROR]:", error)
        }
    }
    
    func start(){
        play()
    }
    
    func stop(){
        playbackTask?.cancel()
        playbackTask = nil
        renderer.flush()
        state = .stopped
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
