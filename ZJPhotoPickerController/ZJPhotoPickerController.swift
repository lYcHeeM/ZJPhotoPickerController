//
//  ZJPhotoPickerController.swift
//  tempaaa
//
//  Created by luozhijun on 2017/8/7.
//  Copyright © 2017年 RickLuo. All rights reserved.
//

import UIKit
import Photos

class ZJPhotoPickerController: UINavigationController {

    fileprivate var albumModels = [ZJAlbumModel]()
    fileprivate var albumListController: ZJPhotoPickerAlbumListController!
    
    var selections = [PHAsset]()
    var selectionsChanged            : (([PHAsset]) -> Void)? = nil
    var selectionsFinished           : (([PHAsset]) -> Void)? = nil
    var willDismissWhenDoneBtnClicked: (([PHAsset]) -> Void)? = nil
    
    var maxSelectionAllowed = 9 {
        didSet {
            albumListController.maxSelectionAllowed = maxSelectionAllowed
        }
    }
    
    required init(albumModels: [ZJAlbumModel], maxSelectionAllowed: Int = 9) {
        let rootVc = ZJPhotoPickerAlbumListController(albumModels: albumModels, maxSelectionAllowed: maxSelectionAllowed)
        super.init(nibName: nil, bundle: nil)
        self.pushViewController(rootVc, animated: false)
        self.albumListController = rootVc
        self.albumModels = albumModels
        self.maxSelectionAllowed = maxSelectionAllowed
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.barStyle  = .black
        navigationBar.tintColor = .white
    }
    
    func pushToCameraRollThumbnailController(animated: Bool) {
        var cameraRollIndex = 0
        for album in albumModels {
            if album.isCameraRoll { break }
            cameraRollIndex += 1
        }
        albumListController.pushingAnimated = animated
        albumListController.tableView(albumListController.tableView, didSelectRowAt: IndexPath(row: cameraRollIndex, section: 0))
    }
}

class ZJPhotoPickerAlbumListController: UITableViewController {
    fileprivate var albumModels = [ZJAlbumModel]()
    fileprivate var maxSelectionAllowed = 9
    fileprivate var thumbnialControllers = [ZJPhotoPickerThumbnailController]()
    fileprivate var selectedAssets = [PHAsset]()
    fileprivate var pushingAnimated: Bool = true
    
    required init(albumModels: [ZJAlbumModel], maxSelectionAllowed: Int) {
        super.init(style: .plain)
        self.albumModels = albumModels
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(dismissNav))
    }
    
    @objc private func dismissNav() {
        navigationController?.dismiss(animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return albumModels.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: ZJPhotoPickerAlbumInfoCell! = tableView.dequeueReusableCell(withIdentifier: "cell") as? ZJPhotoPickerAlbumInfoCell
        if cell == nil {
            cell = ZJPhotoPickerAlbumInfoCell(style: .default, reuseIdentifier: "cell", fixedImageSize: CGSize(width: 80, height: 80))
            cell.accessoryView = UIImageView(image: #imageLiteral(resourceName: "pa_rightArrow"))
        }
        let album = albumModels[indexPath.row]
        cell.imageView?.image = album.cover
        
        let attrTitle = NSMutableAttributedString(string: album.title, attributes: [NSFontAttributeName: UIFont.systemFont(ofSize: 16)])
        attrTitle.append(NSAttributedString(string: "（\(album.count)）", attributes: [NSFontAttributeName: UIFont.systemFont(ofSize: 16), NSForegroundColorAttributeName: UIColor.lightGray]))
        cell.textLabel?.attributedText = attrTitle
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 82
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let hud = ZJPhotoPickerHUD.show(message: "", inView: view, animated: true, needsIndicator: true, hideAfter: TimeInterval.greatestFiniteMagnitude)
        let assets = self.albumModels[indexPath.row].assets
        
        if assets.count >= 1000 {
            DispatchQueue.global().async {
                self.sameAssetsManipulation(assets)
                DispatchQueue.main.async {
                    self.pushing(with: indexPath, assets: assets, hiding: hud)
                }
            }
        } else {
            sameAssetsManipulation(assets)
            pushing(with: indexPath, assets: assets, hiding: hud)
        }
    }
    
    private func sameAssetsManipulation(_ assets: [PHAsset]) {
        for asset in assets {
            asset.isSelected = false
        }
        for selection in self.selectedAssets {
            selection.isSelected = true
        }
        for asset in assets {
            for selection in self.selectedAssets {
                if asset.isSame(to: selection) {
                    asset.isSelected = true
                }
            }
        }
    }
    
    private func pushing(with indexPath: IndexPath, assets: [PHAsset], hiding hud: ZJPhotoPickerHUD?) {
        var thumbnailVc: ZJPhotoPickerThumbnailController!
        if self.thumbnialControllers.count > indexPath.row {
            thumbnailVc = self.thumbnialControllers[indexPath.row]
            thumbnailVc.assets = assets
        } else {
            thumbnailVc = ZJPhotoPickerThumbnailController(assetsModel: self.albumModels[indexPath.row].assets, maxSelectionAllowed: self.maxSelectionAllowed, selectedAssetsPointer: &self.selectedAssets)
            self.thumbnialControllers.append(thumbnailVc)
        }
        hud?.hide(animated: false)
        self.navigationController?.pushViewController(thumbnailVc, animated: pushingAnimated)
        pushingAnimated = true
    }
}

class ZJPhotoPickerAlbumInfoCell: UITableViewCell {
    private var fixedImageSize: CGSize = .zero
    
    required init(style: UITableViewCellStyle, reuseIdentifier: String?, fixedImageSize: CGSize) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.fixedImageSize = fixedImageSize
        imageView?.contentMode = .scaleAspectFill
        imageView?.clipsToBounds = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let imageView = imageView, let image = imageView.image, image.size.width > 0.5 else { return }
        imageView.frame.size = fixedImageSize
        imageView.frame.origin.y = (frame.height - imageView.frame.height)/2
        textLabel?.frame.origin.x = imageView.frame.maxX + 15
    }
}

