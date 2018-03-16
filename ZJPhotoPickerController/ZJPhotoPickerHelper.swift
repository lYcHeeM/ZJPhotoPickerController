//
//  ZJPhotoPickerModel.swift
//  tempaaa
//
//  Created by luozhijun on 2017/8/7.
//  Copyright © 2017年 RickLuo. All rights reserved.
//

import UIKit
import Photos

internal var isIPHONE_X: Bool {
    return UIScreen.instancesRespond(to: #selector(getter: UIDynamicItem.bounds)) ? CGSize(width: 375, height: 812).equalTo(UIScreen.main.bounds.size) : false
}

internal var topBarHeight: CGFloat {
    if isIPHONE_X {
        return 88
    } else {
        return 64
    }
}

internal var bottomAreaHeight: CGFloat {
    if isIPHONE_X {
        return 34
    } else {
        return 0
    }
}

open class ZJPhotoPickerConfiguration {
    static var `default` : ZJPhotoPickerConfiguration {
        return ZJPhotoPickerConfiguration()
    }
    static var thumbnialImageSize = CGSize(width: 240, height: 240)
    open var maxSelectionAllowed      : Int  = 9
    open var assetsSortAscending      : Bool = true
    open var showsSelectedOrder       : Bool = true
    open var allowsVideo              : Bool = true
    open var allowsImage              : Bool = true
    open var allowsSelectOriginalAsset: Bool = true
    /// fullScreenSize by default
    open var imageSizeOnCompletion    : CGSize = CGSize(width: UIScreen.main.bounds.width * UIScreen.main.scale, height: UIScreen.main.bounds.width * UIScreen.main.scale)
}

open class ZJAssetModel: Equatable {
    open var phAsset       : PHAsset!
    open var cachedImage   : UIImage?
    open var isSelected    : Bool = false
    open var selectAnimated: Bool = true
    open var selectedOrder : Int  = 0
    open var canSelect     : Bool = true
    
    public static func ==(lhs: ZJAssetModel, rhs: ZJAssetModel) -> Bool {
        if lhs.phAsset == nil, rhs.phAsset == nil { return true }
        guard lhs.phAsset != nil, rhs.phAsset != nil else { return false }
        return lhs.phAsset!.localIdentifier == rhs.phAsset!.localIdentifier
    }
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
    open var assets = [ZJAssetModel]()
}

open class ZJPhotoPickerHelper {
    fileprivate static var originalNaviBarAppearance = ZJNavigationBarStyle()
    
    /// 如果要获取原图, size参数传PHImageManagerMaximumSize即可.
    open class func images(for assets: [PHAsset], size: CGSize, resizeMode: PHImageRequestOptionsResizeMode = .none, deliveryMode: PHImageRequestOptionsDeliveryMode = .highQualityFormat, completion: @escaping ([UIImage]) -> Void) {
        var result = [UIImage]()
        DispatchQueue.global().async {
            for asset in assets {
                self.image(for: asset, synchronous: true, size: size, resizeMode: resizeMode, deliveryMode: deliveryMode, completion: { (image, _) in
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
    
    @discardableResult
    open class func originalImage(for asset: PHAsset, completion: @escaping (UIImage?, [AnyHashable: Any]?) -> Void) -> PHImageRequestID {
        return image(for: asset, size: PHImageManagerMaximumSize, resizeMode: .exact, completion: completion)
    }
    
    @discardableResult
    open class func image(for asset: PHAsset, synchronous: Bool = false, size: CGSize, resizeMode: PHImageRequestOptionsResizeMode = .none, contentMode: PHImageContentMode = .aspectFill, deliveryMode: PHImageRequestOptionsDeliveryMode = .highQualityFormat, progress: PHAssetImageProgressHandler? = nil, completion: @escaping (UIImage?, [AnyHashable: Any]?) -> Void) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.resizeMode             = resizeMode
        options.isSynchronous          = synchronous
        options.isNetworkAccessAllowed = true
        options.progressHandler        = progress
        options.deliveryMode           = deliveryMode
        
        // 考虑到图片存储在iCloud的情况，实践发现此时用PHCachingImageManager获取到的image很可能为nil，
        // 故下面约定，如果是异步请求，一旦发现PHCachingImageManager给的回调中image为nil，则请求低质量的图片（requestDegradedImage）
        let requestDegradedImage = {
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            PHCachingImageManager.default().requestImage(for: asset, targetSize: ZJPhotoPickerConfiguration.thumbnialImageSize, contentMode: contentMode, options: options, resultHandler: { (image, info) in
                completion(image, info)
            })
        }
        
        // 标识是否进入了PHCachingImageManager的completion
        var metCompletion = false
        // 标识默认的回调是否执行，默认的回调即为上面的`requestDegradedImage`
        var defaultCompletionCalled = false
        if synchronous {
            // 如果同步获取图片，则开一个定时器，1.5秒后，
            // 如果PHCachingImageManager还没有给我们回调，则放弃之，改获取缺省的低质量的(Degraded)图片
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard metCompletion == false else { return }
                defaultCompletionCalled = true
                requestDegradedImage()
            }
        }
        
        return PHCachingImageManager.default().requestImage(for: asset, targetSize: size, contentMode: contentMode, options: options) { image, info in
            guard defaultCompletionCalled == false else { return }
            metCompletion = true
            if image == nil {
                requestDegradedImage()
            }
            
            // 如果发现有错误，并且图片在iCloud中，则尝试以全屏尺寸再获取一遍
            if let _ = info?[PHImageErrorKey] as? NSError, let isIniCloud = info?[PHImageResultIsInCloudKey] as? Bool, isIniCloud {
                let fullScreenSize = UIScreen.main.bounds.size.width * UIScreen.main.scale
                PHCachingImageManager.default().requestImage(for: asset, targetSize: CGSize(width: fullScreenSize, height: fullScreenSize), contentMode: contentMode, options: options, resultHandler: completion)
                return
            }
            
            completion(image, info)
        }
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
        
        var assets   = [ZJAssetModel]()
        let maxCount = 99999
        var counter  = 0
        assetResult.enumerateObjects({ (asset, index, stop) in
            if asset.mediaType == .image && !allowsImage { return }
            if asset.mediaType == .video && !allowsVideo { return }
            
            if counter > maxCount {
                stop.pointee = true
            }
            let assetModel = ZJAssetModel()
            assetModel.phAsset = asset
            assets.append(assetModel)
            counter += 1
        })
        model.assets = assets
        return model
    }
}

class ZJNavigationBarStyle {
    var tintColor: UIColor?
    var barTintColor: UIColor?
    var barStyle = UIBarStyle.default
    var titleAttributes: [String: Any]?
    var normalItemTitleAttributes: [String: Any]?
    var highlightedTitleAttributes: [String: Any]?
}

/// 用于设置和还原导航栏样式，考虑到这样的需求：App有自己的导航栏样式，有可能屏蔽了blur效果，但
/// ZJPhotoPicker却想开启blur效果，所以需要暂时更改导航栏样式，在ZJPhotoPicker退出的时候，
/// 则需要恢复原来的导航栏样式。
extension ZJPhotoPickerHelper {
    static func adjustNaviBarStyle() {
        let style       = UINavigationBar.appearance()
        originalNaviBarAppearance.tintColor    = style.tintColor
        originalNaviBarAppearance.barTintColor = style.barTintColor
        originalNaviBarAppearance.barStyle     = style.barStyle
        originalNaviBarAppearance.titleAttributes = style.titleTextAttributes
        originalNaviBarAppearance.normalItemTitleAttributes = UIBarButtonItem.appearance().titleTextAttributes(for: .normal)
        originalNaviBarAppearance.highlightedTitleAttributes = UIBarButtonItem.appearance().titleTextAttributes(for: .highlighted)
        
        style.barTintColor = nil
        style.tintColor = .white
        style.barStyle = .black
        style.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white, NSFontAttributeName: UIFont.boldSystemFont(ofSize: 17)]
    }
    
    static func resumeNaviBarStyle() {
        let style = UINavigationBar.appearance()
        style.barTintColor = originalNaviBarAppearance.barTintColor
        style.titleTextAttributes = originalNaviBarAppearance.titleAttributes
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


