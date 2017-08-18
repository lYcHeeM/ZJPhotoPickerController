//
//  ZJPhotoPickerModel.swift
//  tempaaa
//
//  Created by luozhijun on 2017/8/7.
//  Copyright © 2017年 RickLuo. All rights reserved.
//

import UIKit
import Photos

internal extension PHAsset {
    private struct AssociatedKeys {
        static var isSelectedKey    = 0
        static var selectedOrderKey = 1
        static var canSelectKey     = 2
        static var cachedImageKey   = 3
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
    var selectedOrder: NSNumber {
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.selectedOrderKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        } get {
            if let value = objc_getAssociatedObject(self, &AssociatedKeys.selectedOrderKey) as? NSNumber {
                return value
            } else {
                return NSNumber(value: 0)
            }
        }
    }
    var canSelect: Bool {
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.canSelectKey, newValue, .OBJC_ASSOCIATION_ASSIGN)
        } get {
            if let value = objc_getAssociatedObject(self, &AssociatedKeys.canSelectKey) as? Bool {
                return value
            } else {
                return true
            }
        }
    }
    var cachedImage: UIImage? {
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.cachedImageKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        } get {
            if let value = objc_getAssociatedObject(self, &AssociatedKeys.cachedImageKey) as? UIImage {
                return value
            } else {
                return nil
            }
        }
    }
    
    func isSame(to other: PHAsset) -> Bool {
        return localIdentifier == other.localIdentifier
    }
}

open class ZJPhotoPickerConfiguration {
    static var `default` : ZJPhotoPickerConfiguration {
        return PAPhotoPickerConfiguration()
    }
    open var maxSelectionAllowed      : Int  = 9
    open var assetsSortAscending      : Bool = true
    open var showsSelectedOrder       : Bool = true
    open var allowsVideo              : Bool = true
    open var allowsImage              : Bool = true
    open var allowsSelectOriginalAsset: Bool = true
    /// fullScreenSize by default
    open var imageSizeOnCompletion    : CGSize = CGSize(width: UIScreen.main.bounds.width * UIScreen.main.scale, height: UIScreen.main.bounds.width * UIScreen.main.scale)
}

open class ZJAlbumModel {
    open var title = ""
    open var count = 0
    open var isCameraRoll = false
    open var result: PHFetchResult<PHAsset>?
    open var firstAsset: PHAsset? {
        didSet {
            guard let firstAsset = firstAsset else { return }
            ZJPhotoPickerHelper.image(for: firstAsset, synchronous: true, size: CGSize(width: 200, height: 200)) { (image, _) in
                self.cover = image
            }
        }
    }
    open var cover: UIImage?
    open var assets = [PHAsset]()
}

open class ZJPhotoPickerHelper {
    
    /// 如果要获取原图, size参数传PHImageManagerMaximumSize即可.
    open class func images(for assets: [PHAsset], size: CGSize, completion: @escaping ([UIImage]) -> Void) {
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
    
    open class func originalImage(for asset: PHAsset, completion: @escaping (UIImage?, [AnyHashable: Any]?) -> Void) {
        image(for: asset, size: PHImageManagerMaximumSize, resizeMode: .exact, completion: completion)
    }
    
    open class func image(for asset: PHAsset, synchronous: Bool = false, size: CGSize, resizeMode: PHImageRequestOptionsResizeMode = .fast, contentMode: PHImageContentMode = .aspectFill, completion: @escaping (UIImage?, [AnyHashable: Any]?) -> Void) {
        let options = PHImageRequestOptions()
        options.resizeMode = resizeMode
        options.isSynchronous = synchronous
        
        PHCachingImageManager.default().requestImage(for: asset, targetSize: size, contentMode: contentMode, options: options, resultHandler: completion)
    }
    
    open class func imageSize(of assets: [PHAsset], synchronous: Bool, completion: @escaping (Int) -> Void) {
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
    
    open class func queryAlbumList(cameraRollOnly: Bool = false, ascending: Bool = true, allowsImage: Bool = true, allowsVideo: Bool = true, completion: @escaping ([ZJAlbumModel]) -> Swift.Void) {
        if !allowsImage && !allowsVideo { completion([]) }
        
        DispatchQueue.global().async {
            let options = PHFetchOptions()
            if !allowsImage {
                options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
            }
            if !allowsVideo {
                options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            }
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: ascending)]
            
            let cameraRoll   = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil)
            let smartAlbums  = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil)
            let streamAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumMyPhotoStream, options: nil)
            let userAlbums   = PHAssetCollection.fetchTopLevelUserCollections(with: nil)
            let sharedAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumCloudShared, options: nil)
            var albums = [smartAlbums, streamAlbums, userAlbums, sharedAlbums]
            if cameraRollOnly {
                albums = [cameraRoll]
            }
            
            var albumModels = [ZJAlbumModel]()
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

public extension Int {
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


