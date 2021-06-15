//
//  ViewController.swift
//  innovationweekstoryboard
//
//  Created by darshan on 6/5/21.
//

import UIKit
import AVFoundation
import CoreML
import Vision
import ImageIO
import AVKit

class AssetData : Hashable {
	
	var name: String = ""
	var path: String = ""
	var avasset: AVAsset?
	var classificationTotalScore = 0.0
	var classificationIdentifier = ""
	var images:[UIImage]?
	var documentDirectoryPath: URL?
	var classifications:[VNClassificationObservation] = []
	var maxLabel: String = ""
	var trimmedPath: URL?
	
	static func == (lhs: AssetData, rhs: AssetData) -> Bool {
		if (lhs.name == rhs.name && lhs.path == rhs.path) {
			return true
		}
		return false
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(path)
	}
}

struct AssetDataRequestHandler {
	static var currentlyProcessingAssetDataName: AssetData?
	static var classifications: [VNClassificationObservation] = []
}

class ViewController: UIViewController {
	
	var classificationText = ""
	var personalizedAssets:[AssetData] = [AssetData]()
	var displayTextArray: [String] = [String]()
	
	@IBOutlet weak var generatePersonalizedVideos: UIButton!
	@IBOutlet weak var activityIndicator: UIActivityIndicatorView!
	// MARK: VIEW CONTROLLER
	override func viewDidLoad() {
		super.viewDidLoad()
		activityIndicator.isHidden = true
		let nc = NotificationCenter.default
		nc.addObserver(self, selector: #selector(notificationHandlerForUpdateLabel), name: Notification.Name("SendUpdatesToUser"), object: nil)
	}

	// MARK: STORYBOARDS
	@IBAction func showPersonalizedVideos(_ sender: Any) {
		if personalizedAssets.count > 0 {
			let vc = MediaTableViewController()
			vc.assetData = personalizedAssets
			self.present(vc, animated: true, completion: nil)
			
//			let assetData = personalizedAssets[0]
//			let player = AVPlayer(url: URL(fileURLWithPath: assetData.path))
//			let vc = AVPlayerViewController()
//			vc.player = player
//			present(vc, animated: true) {
//				vc.player?.play()
//			}
		} else {
			let alert = UIAlertController(title: "Information", message: "You haven't generated any videos as yet.", preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
			self.present(alert, animated: true)
		}
	}
	
	@IBAction func showMediaBrowser(_ sender: Any) {
		let vc = MediaTableViewController()
		vc.assetData = FileManager.getAllAssets()
		self.present(vc, animated: true, completion: nil)
	}
	@IBOutlet weak var textViewForDisplayingUpdates: UITextView!
	@IBAction func generatePersonalizedVideos(_ sender: Any) {
		personalizedAssets.removeAll()
		generatePersonalizedVideos.isHidden = true
		activityIndicator.isHidden = false
		activityIndicator.startAnimating()
		getImageFromAVAsset()
	}
	
	// MARK: VIDEO HANDLERS
	func trimVideos(assetData: AssetData, completionBlock: @escaping (Bool, AssetData?, URL?)->()) throws -> Void {
		let exportSession = AVAssetExportSession(asset: assetData.avasset!, presetName: AVAssetExportPresetHighestQuality)
		let outputURL = try FileManager.createDirectoryForTrimmedFiles()?.appendingPathComponent(assetData.name+".mov")
		exportSession?.outputURL = outputURL
		exportSession?.shouldOptimizeForNetworkUse = true;
		exportSession?.outputFileType = AVFileType.mov;
		
		let startTime = CMTimeMake(value: Int64(5), timescale: 1)
		let stopTime = CMTimeMake(value: Int64(8), timescale: 1)
		let range = CMTimeRangeFromTimeToTime(start: startTime, end: stopTime)
		exportSession?.timeRange = range
		exportSession?.exportAsynchronously(completionHandler: {
			switch exportSession?.status {
			   case .failed:
				print("Export failed: \(String(describing: exportSession?.error != nil ? exportSession?.error!.localizedDescription : "No Error Info"))")
			   case .cancelled:
				   print("Export canceled")
			   case .completed:
				assetData.trimmedPath = outputURL
				let notificationCenter = NotificationCenter.default
				notificationCenter.post(name: Notification.Name("SendUpdatesToUser"), object: nil, userInfo: ["text":"completed trimming video \(assetData.name)"])
				completionBlock(true, assetData, outputURL)
			   default:
				   break
			   }
		})
	}

	func getImagesForAssetAsynchronously(assetData: AssetData, completionHandler: @escaping (AssetData, Bool)-> Void) {
		
		let duration = assetData.avasset!.duration
		let seconds = CMTimeGetSeconds(duration)
		let addition = seconds / 15
		var number = 1.0

		var times = [NSValue]()
		times.append(NSValue(time: CMTimeMake(value: Int64(number), timescale: 1)))
		while number < seconds {
			number += addition
			times.append(NSValue(time: CMTimeMake(value: Int64(number), timescale: 1)))
		}

		struct Formatter {
			static let formatter: DateFormatter = {
				let result = DateFormatter()
				result.dateStyle = .short
				return result
			}()
		}
		let notificationCenter = NotificationCenter.default
		notificationCenter.post(name: Notification.Name("SendUpdatesToUser"), object: nil, userInfo: ["text":"generating images for \(assetData.name)"])

		var timesCounter = 0
		let imageGenerator = AVAssetImageGenerator(asset: assetData.avasset!)
		var images:[UIImage] = []
		imageGenerator.generateCGImagesAsynchronously(forTimes: times) { (requestedTime, cgImage, actualImageTime, status, error) in
			
			let seconds = CMTimeGetSeconds(requestedTime)
			let date = Date(timeIntervalSinceNow: seconds)
			let time = Formatter.formatter.string(from: date)
			timesCounter += 1
			switch status {
			case .succeeded: do {
					if let image = cgImage {
						//print("Generated image for approximate time: \(time)")
						let img = UIImage(cgImage: image)
						images.append(img)
						notificationCenter.post(name: Notification.Name("SendUpdatesToUser"), object: nil, userInfo: ["text":"Reading data \(assetData.name) at \(seconds)s"])
						if timesCounter >= times.count {
							//print("got all images, set the callback")
							assetData.images = images
							notificationCenter.post(name: Notification.Name("SendUpdatesToUser"), object: nil, userInfo: ["text":"Finished data generation for \(assetData.name)"])
							completionHandler(assetData, true)
						}
					}
					else {
						print("Failed to generate a valid image for time: \(time)")
					}
				}

			case .failed: do {
					if let error = error {
						print("Failed to generate image with Error: \(error) for time: \(time)")
					}
					else {
						print("Failed to generate image for time: \(time)")
					}
				}

			case .cancelled: do {
				print("Image generation cancelled for time: \(time)")
				}
			@unknown default:
				print("unknown case")
			}
		}
	}
	
	// MARK: IMAGE GENERATION
	func getImageFromAVAsset() {
		
		var trimmedFolderUrl: URL?
		do {
			trimmedFolderUrl = (try FileManager.createDirectoryForTrimmedFiles())!
			FileManager.deleteAllFilesInDirectory(url: trimmedFolderUrl!)
		} catch {
			print("error deleting videos")
		}
		let docsPath = Bundle.main.resourcePath! + "/videos"
		let fileManager = FileManager.default
		do {
			let docsArray = try fileManager.contentsOfDirectory(atPath: docsPath)
			var testArray:[String] = [docsArray[0]]
			print(docsArray)
			testArray = docsArray
			var assets:[String:[AssetData]] = [String:[AssetData]]()
			var testArrayCount = testArray.count
			for videoPath in testArray {
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
				let notificationCenter = NotificationCenter.default
				notificationCenter.post(name: Notification.Name("SendUpdatesToUser"), object: nil, userInfo: ["text":"Will start generating data for \(assetData.name)"])
				getImagesForAssetAsynchronously(assetData: assetData, completionHandler: { [self] assetData, result in
					if result {
						updateClassificationsForAssetData(for: assetData, completionHandler: { resultAssetData in
							notificationCenter.post(name: Notification.Name("SendUpdatesToUser"), object: nil, userInfo: ["text":"Finished asset classifications \(assetData.name)"])
							testArrayCount -= 1
							var dataset:[String:Float] = [:]
							for classification in resultAssetData.classifications {
								let identifier = dataset[classification.identifier]
								if identifier != nil {
									var sum = (dataset[classification.identifier] ?? 0.0) as Float
									sum += classification.confidence
									dataset[classification.identifier] = sum
									notificationCenter.post(name: Notification.Name("SendUpdatesToUser"), object: nil, userInfo: ["text":"\(assetData.name) Identifier \(classification.identifier) confidence \(classification.confidence)"])
								} else {
									dataset[classification.identifier] = classification.confidence
									notificationCenter.post(name: Notification.Name("SendUpdatesToUser"), object: nil, userInfo: ["text":"\(assetData.name) Identifier \(classification.identifier) confidence \(classification.confidence)"])
								}
							}
							//print("final \(dataset) -- \(resultAssetData.name)")
							notificationCenter.post(name: Notification.Name("SendUpdatesToUser"), object: nil, userInfo: ["text":"Parsing asset \(resultAssetData.name)"])
							var maxClassification : Float = 0.0
							var maxDataLabel = ""
							for data in dataset {
								if data.value > maxClassification {
									maxClassification = data.value
									maxDataLabel = data.key
									print("maxClassification \(maxClassification) \(maxDataLabel)")
								}
							}
							assetData.maxLabel = maxDataLabel
							notificationCenter.post(name: Notification.Name("SendUpdatesToUser"), object: nil, userInfo: ["text":"Maximum confidence in ML model for \(assetData.name) is \(assetData.maxLabel)"])
							var asset = assets[maxDataLabel]
							if asset != nil {
								asset?.append(assetData)
								assets[maxDataLabel] = asset
							} else {
								let assetArray: [AssetData] = [assetData]
								assets[maxDataLabel] = assetArray
							}
							
							if testArrayCount < 1 {
								// add all videos for trimming into a set
								var videoSet: Set<AssetData> = Set<AssetData>()
								for assetVideos in assets {
									for assetData in assetVideos.value {
										videoSet.insert(assetData)
									}
								}
								
								// trim all the videos
								var trimmedAssetDataSet: Set<AssetData> = Set<AssetData>()
								for assetToBeTrimmed in videoSet {
									do {
										notificationCenter.post(name: Notification.Name("SendUpdatesToUser"), object: nil, userInfo: ["text":"calling trimVideo method for asset \(assetToBeTrimmed.name) from set", "status" : ""])
										try trimVideos(assetData: assetToBeTrimmed, completionBlock: { result, assetDataWithTrimmedFile, assetUrl in
											trimmedAssetDataSet.insert(assetDataWithTrimmedFile!)
											if videoSet.contains(assetToBeTrimmed) {
												notificationCenter.post(name: Notification.Name("SendUpdatesToUser"), object: nil, userInfo: ["text":"removing trimmed asset \(assetToBeTrimmed.name) from set", "status" : ""])
												videoSet.remove(assetToBeTrimmed)
											}
											if videoSet.isEmpty {
												// start generating the merged videos
												notificationCenter.post(name: Notification.Name("SendUpdatesToUser"), object: nil, userInfo: ["text":"will start generating merge videos from trimmed videos \(trimmedAssetDataSet.count)", "status" : ""])
												// iterate through the ML models and set the trimmed path to the asset
												var finishedMergingAllModelsCounter = assets.keys.count
												for mlmodelnamekey in assets.keys {
													let assetDataArray = assets[mlmodelnamekey]!
													var assetsToBeMergedArray:[AVAsset] = [AVAsset]()
													for assetData in assetDataArray {
														// get the trimmed asset data
														let idx = trimmedAssetDataSet.firstIndex(of: assetData)
														let trimmedAssetData = trimmedAssetDataSet[idx!]
														assetsToBeMergedArray.append(AVAsset(url: trimmedAssetData.trimmedPath!))
													}
													// start merging the trimmed videos in the ML model as key
													merge(mlmodelName: mlmodelnamekey, arrayVideos: assetsToBeMergedArray, filename: mlmodelnamekey) { exportSession, mlmodelName in
														finishedMergingAllModelsCounter -= 1
														switch exportSession.status {
														   case .failed:
															print("Export failed: \(String(describing: exportSession.error != nil ? exportSession.error!.localizedDescription : "No Error Info"))")
														   case .cancelled:
															   print("Export canceled")
														   case .completed:
															print("finished merging files here", String(exportSession.outputURL!.absoluteString))
															let avasset: AssetData = AssetData()
															avasset.name = "ML model used \(mlmodelName)"
															avasset.avasset = AVAsset(url: exportSession.outputURL!)
															avasset.path = exportSession.outputURL!.path
															personalizedAssets.append(avasset)
															if finishedMergingAllModelsCounter == 0 {
																notificationCenter.post(name: Notification.Name("SendUpdatesToUser"), object: nil, userInfo: ["text":"Merged videos \(exportSession.outputURL?.absoluteString ?? "")", "status" : "finished"])
															} else {
																notificationCenter.post(name: Notification.Name("SendUpdatesToUser"), object: nil, userInfo: ["text":"Finished merging video \(exportSession.outputURL?.absoluteString ?? "") for Model \(mlmodelnamekey)", "status" : "not finished"])
															}
														   default:
															   break
														   }

													}
												}
											}
										})
									} catch {
										print("error trimming videos")
									}
								}
								
//								var maxValuesPerClassification = 0
//								var maxValuesClassification = ""
//								for classification in assets {
//									if classification.value.count > maxValuesPerClassification {
//										maxValuesPerClassification = classification.value.count
//										maxValuesClassification = classification.key
//									}
//								}
//								var avassets: [AVAsset] = [AVAsset]()
//								var trimmedAssetsDictionary: [String:[AVAsset]] = [String:[AVAsset]]()
//								for asset in assets {
//									let assetsDataArray = asset.value
//									notificationCenter.post(name: Notification.Name("SendUpdatesToUser"), object: nil, userInfo: ["text":"Comparing ML model \(asset.key)"])
//
//									//if asset.key == maxValuesClassification {
//										notificationCenter.post(name: Notification.Name("SendUpdatesToUser"), object: nil, userInfo: ["text":"Matched ML Model \(asset.key). Will start trimming videos now. Trimming...."])
//										for  a in assetsDataArray {
//											do {
//												notificationCenter.post(name: Notification.Name("SendUpdatesToUser"), object: nil, userInfo: ["text":"\(a.name)"])
//												try trimVideos(assetData: a, completionBlock: { result, avasset, assetUrl in
//													avassets.append(AVAsset(url: assetUrl!))
//													if avassets.count == assetsDataArray.count {
//														trimmedAssetsDictionary[asset.key] = avassets
//														print("lets merge all the videos\(trimmedAssetsDictionary.keys) \(assets.keys) \(avassets.count)")
//														//avassets.removeAll()
//														if trimmedAssetsDictionary.keys.count == assets.keys.count {
//															print("lets merge all the videos")
//														}
//													}
//												})
//											} catch {
//												print("error trimming videos ", error)
//											}
//										}
//									//}
//								}
							}
//							print("classification text \(descriptionsConfidence)")
//							let sum = descriptionsConfidence.reduce(0, +)
//							print("Sum of Array is : ", sum)
						})
					}
				})
			}
		} catch {
			print(error)
		}
				
//		let avasset = AVAsset(url: URL.init(fileURLWithPath: Bundle.main.path(forResource: "videos/board5", ofType: "MOV")!))
//		let avasset = AVAsset(url: URL.init(fileURLWithPath: Bundle.main.path(forResource: "videos/dog2", ofType: "mp4")!))
//		let avasset = AVAsset(url: URL.init(fileURLWithPath: Bundle.main.path(forResource: "videos/dropdown1", ofType: "MOV")!))
//		let avasset = AVAsset(url: URL.init(fileURLWithPath: Bundle.main.path(forResource: "videos/peacock", ofType: "mov")!))
//		generateImagesAsync(asset: avasset)
	}
	
	func merge(mlmodelName: String, arrayVideos:[AVAsset], filename:String, completion:@escaping (_ exporter: AVAssetExportSession, _ mlmodelName: String) -> ()) -> Void {
		let mainComposition = AVMutableComposition()
		let compositionVideoTrack = mainComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
		var insertTime = CMTime.zero
		  for videoAsset in arrayVideos {
			try! compositionVideoTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: videoAsset.duration), of: videoAsset.tracks(withMediaType: .video)[0], at: insertTime)
	//		try! soundtrackTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: videoAsset.duration), of: videoAsset.tracks(withMediaType: .audio)[0], at: insertTime)
			insertTime = CMTimeAdd(insertTime, videoAsset.duration)
		  }
		compositionVideoTrack?.preferredTransform = arrayVideos[0].preferredTransform
			let soundtrackTrack = mainComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
			do {
				let fileManager = FileManager.default
				let docsArray = try fileManager.contentsOfDirectory(atPath: Bundle.main.resourcePath!)
				for doc in docsArray {
					if doc == "Toybox.m4a" {
						print(doc)
						let audioAsset = AVAsset(url: URL(fileURLWithPath: Bundle.main.resourcePath! + "/Toybox.m4a"))
						try soundtrackTrack?.insertTimeRange(
						CMTimeRangeMake(
						  start: .zero,
						  duration: insertTime),
						of: audioAsset.tracks(withMediaType: .audio)[0],
						at: .zero)
					}
				}
			} catch {
			  print("Failed to load Audio track")
			}
		
		do {
			let outputFileURL = try FileManager.createDirectoryForTrimmedFiles()?.appendingPathComponent(filename+".mp4")
			let fileManager = FileManager.default
			if fileManager.fileExists(atPath: outputFileURL!.absoluteString) {
				try fileManager.removeItem(atPath: outputFileURL!.absoluteString)
			}
			
			let exporter = AVAssetExportSession(asset: mainComposition, presetName: AVAssetExportPresetHighestQuality)

			exporter?.outputURL = outputFileURL
			exporter?.outputFileType = AVFileType.mov
			exporter?.shouldOptimizeForNetworkUse = true

			exporter?.exportAsynchronously {
			  DispatchQueue.main.async {
				completion(exporter!, mlmodelName)
			  }
			}

		} catch {
			print("error merging \(error)")
		}
	}
	
	// MARK: NOTIFICATION
	@objc func notificationHandlerForUpdateLabel(notification: Notification) {
		let userInfo = notification.userInfo as! [String: String]
		DispatchQueue.main.async { [self] in
			let status = userInfo["status"]
			var userInfoText = userInfo["text"]!
			guard status != nil else {
				var textviewtext = textViewForDisplayingUpdates.text
				displayTextArray.append(userInfoText)
				textviewtext = textviewtext! + "\n" + displayTextArray.removeFirst()
				textViewForDisplayingUpdates.text = textviewtext
				textViewForDisplayingUpdates.scrollRangeToVisible(NSMakeRange(0, textviewtext!.count))
				return
			}
			if status == "finished" {
				userInfoText = "Adding graphics to your merged videos"
				addGraphicsToVideos()
			}
			var textviewtext = textViewForDisplayingUpdates.text
			displayTextArray.append(userInfoText)
			textviewtext = textviewtext! + "\n" + displayTextArray.removeFirst()
			textViewForDisplayingUpdates.text = textviewtext
			textViewForDisplayingUpdates.scrollRangeToVisible(NSMakeRange(0, textviewtext!.count))
		}
	}

	func addGraphicsToVideos() {
		let videoEditor = VideoEditor()
		var counter = 0
		let notificationCenter = NotificationCenter.default
		for assetData in personalizedAssets {
			videoEditor.makeBirthdayCard(fromVideoAt: URL(fileURLWithPath: assetData.path), forName: assetData.name) { [self] graphicsVideoURL in
				notificationCenter.post(name: Notification.Name("SendUpdatesToUser"), object: nil, userInfo: ["text":"Generated video using \(assetData.name)"])
				counter += 1
				print("video url \(graphicsVideoURL?.absoluteString ?? "")")
				assetData.path = graphicsVideoURL!.path
				if counter == personalizedAssets.count {
					generatePersonalizedVideos.isHidden = false
					activityIndicator.stopAnimating()
					activityIndicator.isHidden = true
					let alert = UIAlertController(title: "Information", message: "Finished generating personalized videos", preferredStyle: .alert)
					alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
//						let player = AVPlayer(url: graphicsVideoURL!)
//						let vc = AVPlayerViewController()
//						vc.player = player
//						present(vc, animated: true) {
//							vc.player?.play()
//						}
					}))
					self.present(alert, animated: true)
				}
			}
		}
	}
	
	// MARK: COREML
	lazy var classificationRequest: VNCoreMLRequest = {
		do {
			/*
			 Use the Swift class `MobileNet` Core ML generates from the model.
			 To use a different Core ML classifier model, add it to the project
			 and replace `MobileNet` with that model's generated Swift class.
			 */
			// darshan
			let model = try VNCoreMLModel(for: boardclassifier().model)
			
			let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
				self?.processClassifications(for: request, error: error)
			})
			request.imageCropAndScaleOption = .centerCrop
			return request
		} catch {
			fatalError("Failed to load Vision ML model: \(error)")
		}
	}()
	
	/// - Tag: PerformRequests
	func updateClassificationsForAssetData(for assetData:AssetData, completionHandler: @escaping (AssetData)->Void) {
		classificationText = "Classifying..."
		DispatchQueue.global(qos: .userInitiated).sync {
			for pos in (0..<assetData.images!.count) {
				let image = assetData.images![pos]
				let orientation = CGImagePropertyOrientation(image.imageOrientation)
				guard let ciImage = CIImage(image: image) else { fatalError("Unable to create \(CIImage.self) from \(image).") }
				let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
				do {
					//AssetDataRequestHandler.currentlyProcessingAssetDataName = assetData
					let visionModel = try VNCoreMLModel(for: boardclassifier().model)
					try handler.perform([self.classificationRequest])
					//print("classification finished for ",assetData.name, pos)
					if pos >= assetData.images!.count - 1 {
						//print("calling completion handler classification finished for ",assetData.name, pos)
						assetData.classifications = AssetDataRequestHandler.classifications
						AssetDataRequestHandler.classifications.removeAll()
						completionHandler(assetData)
					}
				} catch {
					/*
					 This handler catches general image processing errors. The `classificationRequest`'s
					 completion handler `processClassifications(_:error:)` catches errors specific
					 to processing that request.
					 */
					print("Failed to perform classification.\n\(error.localizedDescription)")
				}
			}
		}
	}
	
	func updateClassifications(for image: UIImage) {
		classificationText = "Classifying..."
		
		let orientation = CGImagePropertyOrientation(image.imageOrientation)
		guard let ciImage = CIImage(image: image) else { fatalError("Unable to create \(CIImage.self) from \(image).") }
		
		DispatchQueue.global(qos: .userInitiated).async {
			let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
			do {
				try handler.perform([self.classificationRequest])
				print("classification finished")
			} catch {
				/*
				 This handler catches general image processing errors. The `classificationRequest`'s
				 completion handler `processClassifications(_:error:)` catches errors specific
				 to processing that request.
				 */
				print("Failed to perform classification.\n\(error.localizedDescription)")
			}
		}
	}
	
	/// Updates the UI with the results of the classification.
	/// - Tag: ProcessClassifications
	func processClassifications(for request: VNRequest, error: Error?) {
		DispatchQueue.main.sync { [self] in
			guard let results = request.results else {
				classificationText = "Unable to classify image.\n\(error!.localizedDescription)"
				return
			}
			// The `results` will always be `VNClassificationObservation`s, as specified by the Core ML model in this project.
			let classifications = results as! [VNClassificationObservation]
		
			if classifications.isEmpty {
				classificationText = "Nothing recognized."
			} else {
				// Display top classifications ranked by confidence in the UI.
				let topClassifications = classifications.prefix(2)
				AssetDataRequestHandler.classifications.insert(contentsOf: topClassifications, at: 0)
				let descriptions = topClassifications.map { classification in
					// Formats the classification for display; e.g. "(0.37) cliff, drop, drop-off".
				   return String(format: "  (%.2f) %@", classification.confidence, classification.identifier)
				}
				classificationText = "Classification:\n" + descriptions.joined(separator: "\n")
				//print("classification text \(classificationText)")
			}
		}
	}
/*
	func generateImagesAsync(assetData: AssetData, asset: AVAsset) {
		
		let duration = asset.duration
		let seconds = CMTimeGetSeconds(duration)
		let addition = seconds / 15
		var number = 1.0

		var times = [NSValue]()
		times.append(NSValue(time: CMTimeMake(value: Int64(number), timescale: 1)))
		while number < seconds {
			number += addition
			times.append(NSValue(time: CMTimeMake(value: Int64(number), timescale: 1)))
		}

		struct Formatter {
			static let formatter: DateFormatter = {
				let result = DateFormatter()
				result.dateStyle = .short
				return result
			}()
		}
		let imageGenerator = AVAssetImageGenerator(asset: asset)
		imageGenerator.generateCGImagesAsynchronously(forTimes: times) { [self] (requestedTime, cgImage, actualImageTime, status, error) in
			let seconds = CMTimeGetSeconds(requestedTime)
			let date = Date(timeIntervalSinceNow: seconds)
			let time = Formatter.formatter.string(from: date)

			switch status {
			case .succeeded: do {
					if let image = cgImage {
						print("Generated image for approximate time: \(time)")
						
						let img = UIImage(cgImage: image)
						updateClassifications(for: img)
						if let data = img.pngData() {
							let filename = self.getDocumentsDirectory().appendingPathComponent(NSUUID().uuidString+".png")
							try? data.write(to: filename)
							print(filename)
						}
					}
					else {
						print("Failed to generate a valid image for time: \(time)")
					}
				}

			case .failed: do {
					if let error = error {
						print("Failed to generate image with Error: \(error) for time: \(time)")
					}
					else {
						print("Failed to generate image for time: \(time)")
					}
				}

			case .cancelled: do {
				print("Image generation cancelled for time: \(time)")
				}
			@unknown default:
				print("unknown case")
			}
		}
	}
*/
}

