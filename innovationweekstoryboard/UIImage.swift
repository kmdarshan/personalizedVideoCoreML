//
//  UIImage.swift
//  innovationweekstoryboard
//
//  Created by darshan on 6/8/21.
//

import Foundation
import UIKit
import AVFoundation

extension UIImage {
	static func generateThumbnailFromAsset(asset: AVAsset, forTime time: CMTime) -> UIImage? {
		let imageGenerator = AVAssetImageGenerator(asset: asset)
		imageGenerator.appliesPreferredTrackTransform = true
		var actualTime: CMTime = CMTime.zero
			do {
				let imageRef = try imageGenerator.copyCGImage(at: time, actualTime: &actualTime)
				let image = UIImage(cgImage: imageRef)
				return image
			} catch let error as NSError {
				print("\(error.description). Time: \(actualTime)")
			}
		return nil
	}
}
