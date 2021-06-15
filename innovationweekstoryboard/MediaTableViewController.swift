//
//  MediaTableViewController.swift
//  innovationweekstoryboard
//
//  Created by darshan on 6/8/21.
//

import Foundation
import UIKit
import AVFoundation
import AVKit

class MediaTableViewController : UITableViewController {
	var selectedIndex : Int = -1
	var assetData:[AssetData] = [AssetData]()
	var player : AVPlayer = AVPlayer()
	var playerLayer = AVPlayerLayer()
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return assetData.count
	}
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cellIdentifier = "assetIdentifier"
		var cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
		if cell == nil {
			cell = UITableViewCell(style: .subtitle, reuseIdentifier: cellIdentifier)
		}
		let asset = assetData[indexPath.row]
		let image = UIImage.generateThumbnailFromAsset(asset: asset.avasset!, forTime: CMTime(seconds: 1, preferredTimescale: 1))
		cell!.detailTextLabel?.text = String(format: "Duration: %.2f",(CMTimeGetSeconds(asset.avasset!.duration)))
		cell?.textLabel?.text = asset.name
		cell?.imageView?.image = image
		//cell.textLabel?.text = asset.name + " Duration: \(CMTimeGetSeconds(asset.avasset!.duration))"
		return cell!
	}
	
	override func viewDidLoad() {
		//tableView.register(UITableViewCell.self, forCellReuseIdentifier: "assetIdentifier")
	}
	
	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		if indexPath.row == selectedIndex
		{
			return 150
		}else{
			return 75
		}
	}
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		player.pause()
		playerLayer.removeFromSuperlayer()
		
		selectedIndex = indexPath.row
		if indexPath.row == selectedIndex{
			selectedIndex = indexPath.row
		}else{
			selectedIndex = -1
		}
		tableView .reloadRows(at: [indexPath], with: .none)
		
		let asset = assetData[indexPath.row]
		let videoURL: URL = URL(fileURLWithPath: asset.path)
//		player = AVPlayer(url: videoURL)
//		playerLayer = AVPlayerLayer(player: player)
//		let tableviewcell = tableView .cellForRow(at: indexPath)
//		guard tableviewcell != nil else {
//			return
//		}
//		playerLayer.frame = tableviewcell!.imageView!.frame
//		tableviewcell?.contentView.layer.addSublayer(playerLayer)
//		player.play()
		
		let player = AVPlayer(url: videoURL)
		let vc = AVPlayerViewController()
		vc.player = player
		present(vc, animated: true) {
			vc.player?.play()
		}
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		selectedIndex = -1
	}
}
