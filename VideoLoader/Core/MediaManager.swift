//
//  VideoManager.swift
//  VideoLoader
//
//  Created by Khanh Anh Kiet on 2026-07-02.
//

import AVFoundation

private nonisolated final class SampleQueue<Element>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Element] = []
    private var finished = false
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
    }

    func tryEnqueue(_ element: Element) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard storage.count < capacity else { return false }
        storage.append(element)
        return true
    }

    func dequeue() -> Element? {
        lock.lock()
        defer { lock.unlock() }
        guard !storage.isEmpty else { return nil }
        return storage.removeFirst()
    }

    func finish() {
        lock.lock()
        finished = true
        lock.unlock()
    }

    func reset() {
        lock.lock()
        storage.removeAll()
        finished = false
        lock.unlock()
    }
    var isDrained: Bool {
        lock.lock()
        defer { lock.unlock() }
        return finished && storage.isEmpty
    }
}

nonisolated final class MediaManager: @unchecked Sendable {

    private let audioSerializationQueue = DispatchQueue(label: "com.app.audioQueue", qos: .userInteractive)
    private let videoSerializationQueue = DispatchQueue(label: "com.app.videoQueue", qos: .userInteractive)
    private let synchronizer: AVSampleBufferRenderSynchronizer
    private let audioRenderer: AVSampleBufferAudioRenderer
    private let videoRenderer: AVSampleBufferVideoRenderer

    private let audioQueue = SampleQueue<CMSampleBuffer>(capacity: 90)
    private let videoQueue = SampleQueue<CMSampleBuffer>(capacity: 30)

    private var audioTask: Task<Void, Never>?

    init(audioRender: AVSampleBufferAudioRenderer, videoRender: AVSampleBufferVideoRenderer) {
        self.synchronizer = AVSampleBufferRenderSynchronizer()
        self.audioRenderer = audioRender
        self.videoRenderer = videoRender
        self.synchronizer.addRenderer(videoRender)
        self.synchronizer.addRenderer(audioRender)
    }

    func prepare() {
        videoQueue.reset()
        audioQueue.reset()

        videoRenderer.requestMediaDataWhenReady(on: videoSerializationQueue) { [weak self] in
            guard let self else { return }
            while self.videoRenderer.isReadyForMoreMediaData {
                guard let sampleBuffer = self.videoQueue.dequeue() else {
                    if self.videoQueue.isDrained {
                        self.videoRenderer.stopRequestingMediaData()
                    }
                    break
                }
                self.videoRenderer.enqueue(sampleBuffer)
            }
        }

        audioRenderer.requestMediaDataWhenReady(on: audioSerializationQueue) { [weak self] in
            guard let self else { return }
            while self.audioRenderer.isReadyForMoreMediaData {
                guard let sampleBuffer = self.audioQueue.dequeue() else {
                    if self.audioQueue.isDrained {
                        self.audioRenderer.stopRequestingMediaData()
                    }
                    break
                }
                self.audioRenderer.enqueue(sampleBuffer)
            }
        }
    }

    func enqueueVideo(pixelBuffer: CVPixelBuffer, pts: CMTime) async {
        guard let sampleBuffer = makeSampleBuffer(from: pixelBuffer, pts: pts) else { return }
        await waitToEnqueue(sampleBuffer, into: videoQueue)
    }
    func startAudio(from stream: AsyncStream<AudioSample>) {
        audioTask = Task.detached(priority: .userInitiated) { [weak self] in
            for await sample in stream {
                if Task.isCancelled { break }
                guard let self else { break }
                await self.waitToEnqueue(sample.audioSampleBuffer, into: self.audioQueue)
            }
            self?.audioQueue.finish()
        }
    }

    func finishVideo() {
        videoQueue.finish()
    }

    private func waitToEnqueue(_ buffer: CMSampleBuffer, into queue: SampleQueue<CMSampleBuffer>) async {
        while !queue.tryEnqueue(buffer) {
            if Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: 5_000_000) // 5ms
        }
    }


    func play() {
        synchronizer.setRate(1.0, time: .zero)
    }

    func pause() {
        synchronizer.rate = 0.0
    }

    func resume() {
        synchronizer.rate = 1.0
    }

    func stop() {
        audioTask?.cancel()
        audioTask = nil
        synchronizer.setRate(0.0, time: .zero)
        audioRenderer.stopRequestingMediaData()
        videoRenderer.stopRequestingMediaData()
        audioRenderer.flush()
        // removingDisplayedImage: true → xóa cả frame cuối đang hiển thị (về màn đen),
        // không để đứng hình.
        videoRenderer.flush(removingDisplayedImage: true)
    }

    private func makeSampleBuffer(from pixelBuffer: CVPixelBuffer, pts: CMTime) -> CMSampleBuffer? {
        var formatDescription: CMVideoFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        guard formatStatus == noErr, let formatDescription else {
            print("[MEDIA] Không tạo được format description: \(formatStatus)")
            return nil
        }

        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: pts,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        let bufferStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard bufferStatus == noErr else {
            print("[MEDIA] Không tạo được sample buffer: \(bufferStatus)")
            return nil
        }
        return sampleBuffer
    }
}
