//
//  AudioSample.swift
//  VideoLoader
//
//  Created by Khanh Anh Kiet on 2026-07-06.
//

import AVFoundation

nonisolated struct AudioSample{
    let audioSampleBuffer: CMSampleBuffer
    let presentationTimeStamp: CMTime
}
