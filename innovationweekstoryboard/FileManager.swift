//
//  FileManager.swift
//  innovationweekstoryboard
//
//  Created by darshan on 6/8/21.
//

import UIKit
import Foundation
import AVFoundation

extension FileManager {
	
	static func getDocumentsDirectory() -> URL {
		let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
		return paths[0]
	}
	
	static func deleteAllFilesInDirectory(url: URL) {
		do {
			let fileURLs = try FileManager.default.contentsOfDirectory(at: url,
																	   includingPropertiesForKeys: nil,
																	   options: .skipsHiddenFiles)
			for fileURL in fileURLs {
				try FileManager.default.removeItem(at: fileURL)
			}
		} catch  { print(error) }
	}
	
	static func createDirectoryForTrimmedFiles() throws -> URL? {
		let manager = FileManager.default
		let rootFolderURL =  try manager.url(
					for: .documentDirectory,
					in: .userDomainMask,
					appropriateFor: nil,
					create: true
				)
		let nestedFolderURL = rootFolderURL.appendingPathComponent("trimmedVideos")
		var isDir:ObjCBool = true
		if !FileManager.default.fileExists(atPath: nestedFolderURL.absoluteString, isDirectory: &isDir) {
			try FileManager.default.createDirectory(at: nestedFolderURL, withIntermediateDirectories: true)
			return nestedFolderURL
		}
		return nil
	}
	
	static func writeImageToFile(img: UIImage, name: String) -> URL? {
		if let data = img.pngData() {
			let filename = FileManager.getDocumentsDirectory().appendingPathComponent(NSUUID().uuidString+"_"+name+".png")
			try? data.write(to: filename)
			return filename
		}
		return nil
	}
	
	static func getAllAssets() -> [AssetData] {
		let docsPath = Bundle.main.resourcePath! + "/videos"
		let fileManager = FileManager.default
		var assets:[AssetData] = [AssetData]()
		do {
			let docsArray = try fileManager.contentsOfDirectory(atPath: docsPath)
			for videoPath in docsArray {
				let assetData = AssetData()
				let fileName = videoPath
				var components = fileName.components(separatedBy: ".")
				if components.count > 1 { // If there is a file extension
					components.removeLast()
					assetData.name = components.joined(separator: ".")
				} else {
					assetData.name = fileName
				}
				assetData.path = docsPath + "/" + videoPath
				let avasset = AVAsset(url: URL.init(fileURLWithPath: assetData.path))
				assetData.avasset = avasset
				assets.append(assetData)
			}
		} catch {
			print("error getting assets")
		}
		return assets
	}
}
