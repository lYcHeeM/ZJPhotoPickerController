//
//  ZJPhotoPickerModel.swift
//  tempaaa
//
//  Created by luozhijun on 2017/8/7.
//  Copyright © 2017年 RickLuo. All rights reserved.
//

import UIKit
import Photos

//class ZJAssetModel: Equatable {
//    var asset: PHAsset!
//    var isSelected = false
//    
//    public static func ==(lhs: ZJAssetModel, rhs: ZJAssetModel) -> Bool {
//        return lhs.asset == rhs.asset && lhs.isSelected == rhs.isSelected
//    }
//}

extension PHAsset {
    private struct AssociatedKeys {
        static var isSelectedKey = 0
    }
    var isSelected: Bool {
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.isSelectedKey, newValue, .OBJC_ASSOCIATION_ASSIGN)
        } get {
            if let value = objc_getAssociatedObject(self, &AssociatedKeys.isSelectedKey) as? Bool {
                return value
            } else {
                return false
            }
        }
    }
    
    func isSame(to other: PHAsset) -> Bool {
        return localIdentifier == other.localIdentifier
    }
}

class ZJAlbumModel {
    var title = ""
    var count = 0
    var isCameraRoll = false
    var result: PHFetchResult<PHAsset>?
    var firstAsset: PHAsset? {
        didSet {
            guard let firstAsset = firstAsset else { return }
            ZJPhotoPickerHelper.image(for: firstAsset, synchronous: true, size: CGSize(width: 400, height: 400)) { (image, _) in
                self.cover = image
            }
        }
    }
    var cover: UIImage?
    var assets = [PHAsset]()
}

class ZJPhotoPickerHelper {    
    class func presentPhotoPicker(in controller: UIViewController, animated: Bool = true, maxSelectionAllowed: Int,  imageQueryFinished: @escaping (ZJPhotoPickerController) -> Swift.Void, completion: (() -> Swift.Void)? = nil) {
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .restricted || status == .denied {
            ZJPhotoPickerHUD.show(message: "Saving failed! Can't access your ablum, check in \"Settings\"->\"Privacy\"->\"Photos\".", inView: controller.view, needsIndicator: false, hideAfter: 2.5)
            return
        }
        let hud = ZJPhotoPickerHUD.show(message: "", inView: controller.view, animated: true, needsIndicator: true, hideAfter: TimeInterval.greatestFiniteMagnitude)
        queryAlbumList { (albumModels) in
            // end hud
            hud?.hide(animated: false)
            let target = ZJPhotoPickerController(albumModels: albumModels, maxSelectionAllowed: maxSelectionAllowed)
            imageQueryFinished(target)
            target.pushToCameraRollThumbnailController(animated: false)
            controller.present(target, animated: animated, completion: completion)
        }
    }
    
    /// 如果要获取原图, size参数传PHImageManagerMaximumSize即可.
    class func images(for assets: [PHAsset], size: CGSize, completion: @escaping ([UIImage]) -> Void) {
        var result = [UIImage]()
        DispatchQueue.global().async {
            for asset in assets {
                self.image(for: asset, synchronous: true, size: size, completion: { (image, _) in
                    if let image = image {
                        result.append(image)
                    }
                })
            }
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    class func originalImage(for asset: PHAsset, completion: @escaping (UIImage?, [AnyHashable: Any]?) -> Void) {
        image(for: asset, size: PHImageManagerMaximumSize, resizeMode: .exact, completion: completion)
    }
    
    class func image(for asset: PHAsset, synchronous: Bool = false, size: CGSize, resizeMode: PHImageRequestOptionsResizeMode = .fast, contentMode: PHImageContentMode = .aspectFill, completion: @escaping (UIImage?, [AnyHashable: Any]?) -> Void) {
        let options = PHImageRequestOptions()
        options.resizeMode = resizeMode
        options.isSynchronous = synchronous
        
        PHCachingImageManager.default().requestImage(for: asset, targetSize: size, contentMode: contentMode, options: options, resultHandler: completion)
    }
    
    class func imageSize(of assets: [PHAsset], synchronous: Bool, completion: @escaping (Int) -> Void) {
        let options = PHImageRequestOptions()
        options.isSynchronous = synchronous
        var size  = 0
        var index = 0
        for asset in assets {
            PHCachingImageManager.default().requestImageData(for: asset, options: options, resultHandler: { (data, dataUTI, orientation, info) in
                index += 1
                size  += data?.count ?? 0
                if index >= assets.count {
                    completion(size)
                }
            })
        }
    }
    
    class func queryAlbumList(ascending: Bool = true, allowsImage: Bool = true, allowsVideo: Bool = true, completion: @escaping ([ZJAlbumModel]) -> Swift.Void) {
        if !allowsImage && !allowsVideo { completion([]) }
        
        let options = PHFetchOptions()
        if !allowsImage {
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        }
        if !allowsVideo {
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        }
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: ascending)]
        
        let smartAlbums  = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil)
        let streamAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumMyPhotoStream, options: nil)
        let userAlbums   = PHAssetCollection.fetchTopLevelUserCollections(with: nil)
        let sharedAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumCloudShared, options: nil)
        let albums = [smartAlbums, streamAlbums, userAlbums, sharedAlbums]
        
        var albumModels = [ZJAlbumModel]()
        DispatchQueue.global().async {
            for item in albums {
                guard let result = item as? PHFetchResult<PHAssetCollection> else { continue }
                result.enumerateObjects({ (collection, index, _) in
                    if !collection.isKind(of: PHAssetCollection.self) { return }
                    // 过滤"最新删除"
                    if collection.assetCollectionSubtype.rawValue >= 214 { return }
                    
                    let assetResult = PHAsset.fetchAssets(in: collection, options: options)
                    guard assetResult.count > 0 else { return }
                    
                    let model = albumModel(with: collection.localizedTitle, ascending: ascending, assetResult: assetResult, allowsImage: allowsImage, allowsVideo: allowsVideo)
                    if collection.assetCollectionSubtype == .smartAlbumUserLibrary {
                        model.isCameraRoll = true
                        albumModels.insert(model, at: 0)
                    } else {
                        albumModels.append(model)
                    }
                })
            }
            
            DispatchQueue.main.async {
                completion(albumModels)
            }
        }
    }
    
    private class func albumModel(with title: String?, ascending: Bool = false, assetResult: PHFetchResult<PHAsset>, allowsImage: Bool = true, allowsVideo: Bool = false) -> ZJAlbumModel {
        let model    = ZJAlbumModel()
        model.title  = title ?? ""
        model.count  = assetResult.count
        model.result = assetResult
        if ascending {
            model.firstAsset = assetResult.lastObject
        } else {
            model.firstAsset = assetResult.firstObject
        }
        
        var assets   = [PHAsset]()
        let maxCount = 99999
        var counter  = 0
        assetResult.enumerateObjects({ (asset, index, stop) in
            if asset.mediaType == .image && !allowsImage { return }
            if asset.mediaType == .video && !allowsVideo { return }
            
            if counter > maxCount {
                stop.pointee = true
            }
            assets.append(asset)
            counter += 1
        })
        model.assets = assets
        return model
    }
}

extension Int {
    var bytesSize: String {
        let mbAmount   = Double(1024 * 1024)
        let doubleSelf = Double(self)
        if doubleSelf > 0.1 * mbAmount {
            return String(format: "%.1fM", doubleSelf/mbAmount)
        } else if doubleSelf >= 1024 {
            return String(format: "%.0fK", doubleSelf/1024)
        } else {
            return "\(self)B"
        }
    }
}


