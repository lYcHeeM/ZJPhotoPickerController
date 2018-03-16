//
//  ZJPhotoPickerThumbnailController.swift
//  tempaaa
//
//  Created by luozhijun on 2017/8/7.
//  Copyright © 2017年 RickLuo. All rights reserved.
//

import UIKit
import Photos
import ZJImageBrowser

class ZJPhotoPickerThumbnailController: UIViewController {
    var assets = [ZJAssetModel]() {
        didSet {
            collectionView.reloadData()
        }
    }
    var isSelectionFull: Bool = false {
        didSet {
            for asset in self.assets {
                if !asset.isSelected {
                    if asset.canSelect == !isSelectionFull {
                        return
                    } else {
                        asset.canSelect = !isSelectionFull
                    }
                }
            }
            collectionView.reloadData()
        }
    }
    
    fileprivate var collectionView   : UICollectionView!
    fileprivate let bottomBarHeight  : CGFloat = 44
    fileprivate var doneButton       : UIButton!
    fileprivate var originalSizeCheck: UIButton!
    fileprivate var previewButton    : UIButton!
    fileprivate var maxSelectionAllowed = 9
    fileprivate var selectedAssetsPointer  : UnsafeMutablePointer<[ZJAssetModel]>!
    fileprivate var sumOfImageSizePointer  : UnsafeMutablePointer<Int>!
    fileprivate var isOriginalPointer      : UnsafeMutablePointer<Bool>!
    fileprivate var isSelectionsFullPointer: UnsafeMutablePointer<Bool>!
    
    fileprivate var previewingLocatedIndexPath: IndexPath?
    
    required init(assets: [ZJAssetModel], selectedAssetsPointer: UnsafeMutablePointer<[ZJAssetModel]>, sumOfImageSizePointer: UnsafeMutablePointer<Int>, isOriginalPointer: UnsafeMutablePointer<Bool>, isSelectionsFullPointer: UnsafeMutablePointer<Bool>) {
        super.init(nibName: nil, bundle: nil)
        self.assets                  = assets
        self.selectedAssetsPointer   = selectedAssetsPointer
        self.sumOfImageSizePointer   = sumOfImageSizePointer
        self.isOriginalPointer       = isOriginalPointer
        self.isSelectionsFullPointer = isSelectionsFullPointer
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
        acquireConfiguration()
    }
    
    private func acquireConfiguration() {
        guard let naviVC = navigationController as? ZJPhotoPickerController else { return }
        maxSelectionAllowed = naviVC.configuration.maxSelectionAllowed
        originalSizeCheck.isHidden = !naviVC.configuration.allowsSelectOriginalAsset
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        originalSizeCheck.isSelected = isOriginalPointer.pointee
        refreshBottomBar()
    }
}

//MARK: - Setup UI 
extension ZJPhotoPickerThumbnailController {
    fileprivate func setupUI() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "back_leftButton"), style: .plain, target: self, action: #selector(back))
        let cancel = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(dismissNav))
        navigationItem.rightBarButtonItems = [cancel]
        
        let doneButtonWidth : CGFloat = 62
        let vPadding        : CGFloat = 8
        let hPadding        : CGFloat = 12
        let doneButtonHeight: CGFloat = bottomBarHeight - 2 * vPadding
        
        let flowLayout = UICollectionViewFlowLayout()
        let itemCountInOneLine = 4
        flowLayout.minimumInteritemSpacing = 3
        flowLayout.minimumLineSpacing = 3
        let itemSize = (view.frame.width - CGFloat(itemCountInOneLine - 1) * flowLayout.minimumInteritemSpacing) / CGFloat(itemCountInOneLine)
        flowLayout.itemSize = CGSize(width: itemSize, height: itemSize)
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: flowLayout)
        collectionView.contentInset.bottom += bottomBarHeight
        collectionView.backgroundColor = view.backgroundColor
        collectionView.register(ZJPhotoPickerThumbnailCell.self, forCellWithReuseIdentifier: ZJPhotoPickerThumbnailCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate   = self
        collectionView.scrollToItem(at: IndexPath(item: assets.count - 1, section: 0), at: .bottom, animated: false)
        collectionView.contentOffset.y += topBarHeight
        view.addSubview(collectionView)
        
        let bottomBar = UIToolbar()
        view.addSubview(bottomBar)
        bottomBar.barStyle = .black
        bottomBar.frame = CGRect(x: 0, y: view.frame.height - bottomBarHeight - bottomAreaHeight, width: view.frame.width, height: bottomBarHeight)
        if isIPHONE_X {
            let bottomAreaBgView = UIToolbar()
            bottomAreaBgView.barStyle = .black
            bottomAreaBgView.clipsToBounds = true
            view.addSubview(bottomAreaBgView)
            bottomAreaBgView.frame = CGRect(x: 0, y: bottomBar.frame.maxY, width: view.frame.width, height: bottomAreaHeight)
        }
        
        doneButton = UIButton()
        doneButton.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        let bgImage = UIImage(color: UIColor.deepOrange)?.stretchable
        let disableImage = UIImage(color: UIColor.gray)?.stretchable
        doneButton.setBackgroundImage(bgImage, for: .normal)
        doneButton.setBackgroundImage(disableImage, for: .disabled)
        doneButton.setTitleColor(.white, for: .normal)
        doneButton.frame.size = CGSize(width: doneButtonWidth, height: doneButtonHeight)
        doneButton.layer.masksToBounds = true
        doneButton.layer.cornerRadius  = 3
        doneButton.layer.backgroundColor = UIColor.green.cgColor
        doneButton.addTarget(self, action: #selector(doneButtonClicked), for: .touchUpInside)
        let doneItem = UIBarButtonItem(customView: doneButton)
        
        originalSizeCheck = UIButton()
        originalSizeCheck.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        originalSizeCheck.setTitle(" 原图 ", for: .normal)
        originalSizeCheck.setImage(#imageLiteral(resourceName: "btn_unselected_round"), for: .normal)
        originalSizeCheck.setImage(#imageLiteral(resourceName: "btn_selected_round"), for: .selected)
        originalSizeCheck.setImage(#imageLiteral(resourceName: "btn_unselected_round"), for: .disabled)
        originalSizeCheck.sizeToFit()
        originalSizeCheck.addTarget(self, action: #selector(originalSizeChecked), for: .touchUpInside)
        let sizeCheckItem = UIBarButtonItem(customView: originalSizeCheck)
        
        previewButton = UIButton(type: .system)
        bottomBar.addSubview(previewButton)
        previewButton.tintColor = .white
        previewButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        previewButton.setTitle("预览", for: .normal)
        previewButton.sizeToFit()
        previewButton.frame = CGRect(x: hPadding, y: (bottomBar.frame.height - previewButton.bounds.height)/2, width: previewButton.bounds.width, height: previewButton.bounds.height)
        previewButton.addTarget(self, action: #selector(previewButtonClicked), for: .touchUpInside)
        let previewItem = UIBarButtonItem(customView: previewButton)
        
        // Tag 给toolBar设置item, 避免直接把子视图加在toolBar上, iOS 11 便会出问题, 但如果设置item的话, Apple会保证Api的toolBar本地的api的有效性.
        let flexibleItem1 = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let flexibleItem2 = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let leftSpaceItem = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        let rightSpaceItem = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        leftSpaceItem.width = -5
        rightSpaceItem.width = -5
        bottomBar.items = [leftSpaceItem, previewItem, flexibleItem1, sizeCheckItem, flexibleItem2, doneItem, rightSpaceItem]
        
        // Realized memory increases infinitely when scrolling UICollectionView, I fixed it by using an alternative way to register 3D Touch previewing. (Calling 'registerForPreviewing' method frequently will increase memory occupation significantly and permanently!)
        // It is best to call this method as few as possible.
        // 重复调用"registerForPreviewing"方法会显著地增加app的内存占用, 而且无法得到释放, 即使进入后台模式也是如此.
        // 好的做法是尽可能少地注册, 比如给根视图注册, 通过设置UIViewControllerPreviewing的sourceRect来控制当3dtouch触发时根视图中需要突出显示的区域, 比如某个cell.
        if #available(iOS 9.0, *) {
            registerForPreviewing(with: self, sourceView: collectionView)
        }
    }
    
    @objc private func back() {
        guard let naviVc = navigationController as? ZJPhotoPickerController else { return }
        naviVc.selections = selectedAssetsPointer.pointee.map({ (model) -> PHAsset in
            return model.phAsset
        })
        naviVc.selectionsFinished?(naviVc.selections)
        naviVc.popViewController(animated: true)
    }
    
    @objc private func dismissNav() {
        navigationController?.dismiss(animated: true, completion: nil)
    }
    
    @objc private func doneButtonClicked() {
        guard let naviVc = navigationController as? ZJPhotoPickerController else { return }
        naviVc.selections = selectedAssetsPointer.pointee.map({ (model) -> PHAsset in
            return model.phAsset
        })
        let hud = ZJPhotoPickerHUD.show(message: nil, inView: view, hideAfter: TimeInterval.greatestFiniteMagnitude)
        var size = naviVc.configuration.imageSizeOnCompletion
        if isOriginalPointer.pointee == true {
            size = PHImageManagerMaximumSize
        }
        ZJPhotoPickerHelper.images(for: naviVc.selections, size: size, resizeMode: .fast) { (images) in
            hud?.hide(animated: false)
            naviVc.willDismissWhenDoneBtnClicked?(images, naviVc.selections)
            naviVc.dismiss(animated: true) {
                naviVc.didDismissWhenDoneBtnClicked?(images, naviVc.selections)
            }
        }
    }
    
    @objc private func originalSizeChecked() {
        originalSizeCheck.isSelected = !originalSizeCheck.isSelected
        isOriginalPointer.pointee = originalSizeCheck.isSelected
        refreshBottomBar()
    }
    
    fileprivate func refreshBottomBar() {
        let count = selectedAssetsPointer.pointee.count
        doneButton.isEnabled    = count > 0
        previewButton.isEnabled = count > 0
        if count > 0 {
            doneButton.setTitle("完成(\(count))", for: .normal)
        } else {
            doneButton.setTitle("完成", for: .normal)
        }
        if sumOfImageSizePointer.pointee > 0, originalSizeCheck.isSelected {
            self.originalSizeCheck.setTitle(" 原图 \(sumOfImageSizePointer.pointee.bytesSize)", for: .normal)
        } else {
            self.originalSizeCheck.setTitle(" 原图 ", for: .normal)
        }
        self.originalSizeCheck.sizeToFit()
        self.originalSizeCheck.center = CGPoint(x: self.view.frame.width/2, y: self.bottomBarHeight/2)
    }
    
    @objc private func previewButtonClicked() {
        guard let asset = selectedAssetsPointer.pointee.first else { return }
        imageButtonClicked(asset: asset)
    }
}

extension ZJPhotoPickerThumbnailController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ZJPhotoPickerThumbnailCell.reuseIdentifier, for: indexPath) as! ZJPhotoPickerThumbnailCell
        cell.asset = assets[indexPath.item]
        if let naviVc = self.navigationController as? ZJPhotoPickerController {
            cell.showsSelectedOrder = naviVc.configuration.showsSelectedOrder
        }
        weak var weakInstance = cell
        cell.selectButtonClicked = { [weak self] asset in
            guard let asset = asset, let `self` = self, let cell = weakInstance else { return }
            self.selectButtonClicked(on: cell, asset: asset)
        }
        cell.imageButtonClicked = { [weak self] asset in
            guard let asset = asset, let `self` = self else { return }
            self.imageButtonClicked(asset: asset)
        }
        return cell
    }
    
    fileprivate func selectButtonClicked(on cell: ZJPhotoPickerThumbnailCell, asset: ZJAssetModel) {
        var selectionChanged         = false
        var selectionsJustUnFull     = false
        var selectionDeletedAtMiddle = false
        asset.selectAnimated         = true
        if !asset.isSelected {
            if self.selectedAssetsPointer.pointee.count < self.maxSelectionAllowed {
                asset.isSelected = true
                if !self.selectedAssetsPointer.pointee.contains(asset) { // 防止重复添加
                    self.selectedAssetsPointer.pointee.append(asset)
                    asset.selectedOrder = self.selectedAssetsPointer.pointee.count
                    ZJPhotoPickerHelper.imageSize(of: [asset.phAsset], synchronous: true, completion: { (size) in
                        self.sumOfImageSizePointer.pointee += size
                    })
                    selectionChanged = true
                    if self.selectedAssetsPointer.pointee.count >= self.maxSelectionAllowed {
                        self.isSelectionsFullPointer.pointee = true
                        for asset in self.assets {
                            if !asset.isSelected {
                                asset.canSelect = false
                            }
                        }
                        collectionView.reloadData()
                        // 使reloadData同步完成
                        collectionView.layoutIfNeeded()
                    } else {
                        cell.refreshButton(with: asset, animated: true)
                    }
                    asset.selectAnimated = false
                }
            } else {
                let alert = UIAlertController(title: nil, message: "您最多只能一次性选择\(self.maxSelectionAllowed)张照片", preferredStyle: .alert)
                let action = UIAlertAction(title: "确定", style: .default, handler: nil)
                alert.addAction(action)
                self.present(alert, animated: true, completion: nil)
            }
        } else {
            asset.isSelected = false
            if var index = self.selectedAssetsPointer.pointee.index(of: asset) {
                self.selectedAssetsPointer.pointee.remove(at: index)
                if self.selectedAssetsPointer.pointee.count == self.maxSelectionAllowed - 1 {
                    selectionsJustUnFull = true
                    self.isSelectionsFullPointer.pointee = false
                }
                if index < self.selectedAssetsPointer.pointee.count {
                    selectionDeletedAtMiddle = true
                    let startIndex = index
                    for _ in startIndex..<self.selectedAssetsPointer.pointee.count {
                        self.selectedAssetsPointer.pointee[index].selectedOrder = index + 1
                        index += 1
                    }
                }
                ZJPhotoPickerHelper.imageSize(of: [asset.phAsset], synchronous: true, completion: { (size) in
                    self.sumOfImageSizePointer.pointee -= size
                    if self.sumOfImageSizePointer.pointee <= 0 {
                        self.sumOfImageSizePointer.pointee = 0
                    }
                })
                cell.refreshButton(with: asset)
                selectionChanged = true
            }
            asset.selectAnimated = true
        }
        
        guard selectionChanged else { return }
        self.refreshBottomBar()
        guard let naviVc = self.navigationController as? ZJPhotoPickerController else { return }
        naviVc.selections = self.selectedAssetsPointer.pointee.map({ (model) -> PHAsset in
            return model.phAsset
        })
        naviVc.selectionsChanged?(naviVc.selections)
        
        if selectionDeletedAtMiddle {
            collectionView.reloadData()
        }
        
        if selectionsJustUnFull {
            for asset in self.assets {
                asset.canSelect = true
            }
            collectionView.reloadData()
        }
    }
    
    fileprivate func imageButtonClicked(asset: ZJAssetModel, showBrowserAnimated: Bool = true) {
        var imageWrappers  = [ZJImageWrapper]()
        var needsPageIndex = false
        var initialIndex   = 0
        if self.selectedAssetsPointer.pointee.contains(asset) {
            for asset in selectedAssetsPointer.pointee {
                let wrapper = ZJImageWrapper(highQualityImageUrl: nil, asset: asset.phAsset, shouldDownloadImage: false, placeholderImage: asset.cachedImage, imageContainer: nil)
                imageWrappers.append(wrapper)
            }
            initialIndex = asset.selectedOrder - 1
            needsPageIndex = true
        } else {
            let wrapper = ZJImageWrapper(highQualityImageUrl: nil, asset: asset.phAsset, shouldDownloadImage: false, placeholderImage: asset.cachedImage, imageContainer: nil)
            imageWrappers = [wrapper]
        }
        let browser = ZJImageBrowser(imageWrappers: imageWrappers, initialIndex: initialIndex)
        browser.needsSaveButton = false
        browser.needsPageIndex  = needsPageIndex
        browser.show(inView: navigationController?.view, animated: showBrowserAnimated, enlargingAnimated: showBrowserAnimated)
    }
}

@available(iOS 9.0, *)
extension ZJPhotoPickerThumbnailController: UIViewControllerPreviewingDelegate {
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        let point = previewingContext.sourceView.convert(location, to: collectionView)
        guard
            let indexPath   = collectionView.indexPathForItem(at: point),
            let cell        = collectionView.cellForItem(at: indexPath) as? ZJPhotoPickerThumbnailCell,
            let asset       = cell.asset
            else { return nil }
        previewingLocatedIndexPath = indexPath
        var placeholder: UIImage? = nil
        ZJPhotoPickerHelper.image(for: asset.phAsset, synchronous: true, size: CGSize(width: 200, height: 200), resizeMode: .fast, completion: { (image, info) in
            placeholder = image
        })
        previewingContext.sourceRect = cell.frame
        let wrapper = ZJImageWrapper(highQualityImageUrl: nil, asset: asset.phAsset, shouldDownloadImage: false, placeholderImage: placeholder, imageContainer: nil)
        let target = ZJImageBrowserPreviewingController(imageWrapper: wrapper)
        target.preferredContentSize = target.supposedContentSize(with: placeholder)
        target.needsSaveAction = false
        target.needsCopyAction = false
        return target
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        guard
            let indexPath   = previewingLocatedIndexPath,
            let cell        = collectionView.cellForItem(at: indexPath) as? ZJPhotoPickerThumbnailCell,
            let asset       = cell.asset
            else { return }
        imageButtonClicked(asset: asset, showBrowserAnimated: false)
    }
}

class ZJPhotoPickerThumbnailCell: UICollectionViewCell {
    static let reuseIdentifier = "ZJPhotoPickerThumbnailCell"
    fileprivate var imageButton  = UIButton()
    fileprivate var selectButton = PAPohtoPickerSelectButton()
    fileprivate var assetId: String!
    fileprivate var imageRequestId: PHImageRequestID?
    
    var showsSelectedOrder : Bool = true
    var imageButtonClicked : ((ZJAssetModel?) -> Void)?
    var selectButtonClicked: ((ZJAssetModel?) -> Void)?
    
    var asset: ZJAssetModel? {
        didSet {
            guard let asset = asset else { return }
            assetId = asset.phAsset.localIdentifier
            var imageSize = imageButton.bounds.size
            if imageSize.width < 240 {
                imageSize = CGSize(width: 240, height: 240)
            }
            if asset.cachedImage == nil {
                if let imageRequestId = imageRequestId, imageRequestId != PHInvalidImageRequestID {
                    PHImageManager.default().cancelImageRequest(imageRequestId)
                }
                imageRequestId = ZJPhotoPickerHelper.image(for: asset.phAsset, size: imageSize, resizeMode: .exact) { (image, _) in
                    guard self.assetId == asset.phAsset.localIdentifier else { return }
                    self.imageButton.setImage(image, for: .normal)
                    asset.cachedImage = image
                }
            } else {
                imageButton.setImage(asset.cachedImage, for: .normal)
            }
            refreshButton(with: asset, animated: asset.selectAnimated)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(imageButton)
        imageButton.clipsToBounds = true
        imageButton.imageView?.contentMode = .scaleAspectFill
        imageButton.addTarget(self, action: #selector(imageButtonDidClick), for: .touchUpInside)
        
        addSubview(selectButton)
        selectButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        selectButton.setBackgroundImage(#imageLiteral(resourceName: "btn_unselected"), for: .normal)
        selectButton.setBackgroundImage(#imageLiteral(resourceName: "btn_selected"), for: .selected)
        selectButton.sizeToFit()
        selectButton.addTarget(self, action: #selector(selectButtonDidClick), for: .touchUpInside)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func refreshButton(with asset: ZJAssetModel, animated: Bool = true) {
        selectButton.isSelected = asset.isSelected
        if showsSelectedOrder {
            if asset.selectedOrder > 0 {
                selectButton.setBackgroundImage(#imageLiteral(resourceName: "btn_order"), for: .selected)
                selectButton.setTitle("\(asset.selectedOrder)", for: .selected)
            } else {
                selectButton.setBackgroundImage(#imageLiteral(resourceName: "btn_unselected"), for: .normal)
                selectButton.setBackgroundImage(#imageLiteral(resourceName: "btn_selected"), for: .selected)
            }
        } else {
            selectButton.setBackgroundImage(#imageLiteral(resourceName: "btn_unselected"), for: .normal)
            selectButton.setBackgroundImage(#imageLiteral(resourceName: "btn_selected"), for: .selected)
        }
        // 实践发现给大量button(似乎是15个以上)的enabled置为false, 会有很大的图形性能损耗, 首先从刷新colletionView开始直到对应button的外观变为enabled为false的外观, 大概用了1秒; 其次, 滑动collectionView会有很大的帧率丢失, 从之前的60帧变为35帧左右.
//        imageButton.isEnabled = asset.canSelect
        // 故改为控制isUserInteractionEnabled和alpha.
        if asset.canSelect {
            imageButton.alpha = 1
        } else {
            imageButton.alpha = 0.5
        }
        if asset.isSelected, animated {
            selectButton.layer.add(selectionAnimation, forKey: "")
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageButton.frame = bounds
        let padding: CGFloat = 3
        let buttonSize: CGFloat = 20
        selectButton.frame = CGRect(x: frame.width - buttonSize - padding, y: frame.height - buttonSize - padding, width: buttonSize, height: buttonSize)
    }
    
    @objc private func selectButtonDidClick() {
        selectButtonClicked?(asset)
    }
    
    @objc private func imageButtonDidClick() {
        imageButtonClicked?(asset)
    }
    
    private var selectionAnimation: CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.duration = 0.25
        animation.isRemovedOnCompletion = true
        animation.fillMode = kCAFillModeForwards
        animation.keyTimes = [
            NSNumber(floatLiteral: 0.6),
            NSNumber(floatLiteral: 0.4)
        ]
        animation.values = [
            NSValue(caTransform3D: CATransform3DMakeScale(1.2, 1.2, 1.0)),
            NSValue(caTransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0))
        ]
        return animation
    }
}

class PAPohtoPickerSelectButton: UIButton {
    /// 扩大点击区域
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let coefficient: CGFloat = 2.2
        let enlargedBounds = CGRect(x: -bounds.width * (coefficient - 1), y: -bounds.height * (coefficient - 1), width: bounds.width * coefficient, height: bounds.height * coefficient)
        return enlargedBounds.contains(point)
    }
}


