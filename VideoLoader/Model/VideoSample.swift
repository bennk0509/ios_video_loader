//
//  VideoSample.swift
//  VideoLoader
//
//  Created by Khanh Anh Kiet on 2026-06-19.
//

import CoreMedia

//THIS STRUCT CONTAIN CMSAMPLEBUFFER also PTS and isKeyFrame
//This Struct used for transfer data from AVAssetReader to Decodec
struct VideoSample{
    let videoSampleBuffer: CMSampleBuffer
    let presentationTimeStamp: CMTime
    let isKeyFrame: Bool
}

