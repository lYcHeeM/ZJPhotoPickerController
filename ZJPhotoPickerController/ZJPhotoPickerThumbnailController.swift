//
//  ZJPhotoPickerThumbnailController.swift
//  tempaaa
//
//  Created by luozhijun on 2017/8/7.
//  Copyright © 2017年 RickLuo. All rights reserved.
//

import UIKit
import Photos

class ZJPhotoPickerThumbnailController: UIViewController {

    var assets = [PHAsset]() {
        didSet {
            collectionView.reloadData()
        }
    }
    fileprivate var collectionView   : UICollectionView!
    fileprivate let bottomBarHeight  : CGFloat = 44
    fileprivate var doneButton       : UIButton!
    fileprivate var originalSizeCheck: UIButton!
    fileprivate var previewButton    : UIButton!
    fileprivate var maxSelectionAllowed = 99
    fileprivate var selectedAssetsPointer: UnsafeMutablePointer<[PHAsset]>!
    fileprivate var sumOfImageSizePointer: UnsafeMutablePointer<Int>!
    fileprivate var isOriginalPointer    : UnsafeMutablePointer<Bool>!
    
    required init(assets: [PHAsset], maxSelectionAllowed: Int = 9, selectedAssetsPointer: UnsafeMutablePointer<[PHAsset]>, sumOfImageSizePointer: UnsafeMutablePointer<Int>, isOriginalPointer: UnsafeMutablePointer<Bool>!) {
        super.init(nibName: nil, bundle: nil)
        self.assets                = assets
        self.selectedAssetsPointer = selectedAssetsPointer
        self.sumOfImageSizePointer = sumOfImageSizePointer
        self.isOriginalPointer     = isOriginalPointer
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        originalSizeCheck.isSelected = isOriginalPointer.pointee
        refreshBottomBar()
    }
    
    deinit {
        debugPrint("--ZJPhotoPickerThumbnailController")
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
        let pixel = 1/UIScreen.main.scale
        let itemCountInOneLine = 4
        flowLayout.minimumInteritemSpacing = 2*pixel
        flowLayout.minimumLineSpacing = 2*pixel
        let itemSize = (view.frame.width - CGFloat(itemCountInOneLine - 1) * flowLayout.minimumInteritemSpacing) / CGFloat(itemCountInOneLine)
        flowLayout.itemSize = CGSize(width: itemSize, height: itemSize)
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: flowLayout)
        collectionView.contentInset.bottom += bottomBarHeight
        collectionView.backgroundColor = view.backgroundColor
        collectionView.register(ZJPhotoPickerThumbnailCell.self, forCellWithReuseIdentifier: ZJPhotoPickerThumbnailCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate   = self
        collectionView.scrollToItem(at: IndexPath(item: assets.count - 1, section: 0), at: .bottom, animated: false)
        collectionView.contentOffset.y += 64
        view.addSubview(collectionView)
        
        let bottomBar = UIToolbar()
        view.addSubview(bottomBar)
        bottomBar.barStyle = .black
        bottomBar.frame = CGRect(x: 0, y: view.frame.height - bottomBarHeight, width: view.frame.width, height: bottomBarHeight)
        
        doneButton = UIButton()
        bottomBar.addSubview(doneButton)
        doneButton.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        let bgImage = UIImage(color: UIColor.deepOrange)?.stretchable
        let disableImage = UIImage(color: UIColor.gray)?.stretchable
        doneButton.setBackgroundImage(bgImage, for: .normal)
        doneButton.setBackgroundImage(disableImage, for: .disabled)
        doneButton.setTitleColor(.white, for: .normal)
        doneButton.frame = CGRect(x: view.frame.width - hPadding - doneButtonWidth, y: vPadding, width: doneButtonWidth, height: doneButtonHeight)
        doneButton.layer.masksToBounds = true
        doneButton.layer.cornerRadius  = 3
        doneButton.layer.backgroundColor = UIColor.green.cgColor
        doneButton.addTarget(self, action: #selector(doneButtonClicked), for: .touchUpInside)
        
        originalSizeCheck = UIButton()
        bottomBar.addSubview(originalSizeCheck)
        originalSizeCheck.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        originalSizeCheck.setTitle(" 原图 ", for: .normal)
        originalSizeCheck.setImage(#imageLiteral(resourceName: "NoSelectRoundBtn"), for: .normal)
        originalSizeCheck.setImage(#imageLiteral(resourceName: "SelectRoundBtn"), for: .selected)
        originalSizeCheck.setImage(#imageLiteral(resourceName: "NoSelectRoundBtn"), for: .disabled)
        originalSizeCheck.sizeToFit()
        originalSizeCheck.addTarget(self, action: #selector(originalSizeChecked), for: .touchUpInside)
        
        previewButton = UIButton(type: .system)
        bottomBar.addSubview(previewButton)
        previewButton.tintColor = .white
        previewButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        previewButton.setTitle("预览", for: .normal)
        previewButton.sizeToFit()
        previewButton.frame = CGRect(x: hPadding, y: (bottomBar.frame.height - previewButton.bounds.height)/2, width: previewButton.bounds.width, height: previewButton.bounds.height)
        previewButton.addTarget(self, action: #selector(previewButtonClicked), for: .touchUpInside)
    }
    
    @objc private func back() {
        guard let naviVc = navigationController as? ZJPhotoPickerController else { return }
        naviVc.selections = selectedAssetsPointer.pointee
        naviVc.selectionsFinished?(selectedAssetsPointer.pointee)
        naviVc.popViewController(animated: true)
        // 返回到相册列表时, 考虑到用户相册可能有更新, 重新查询所有相册
        let hud = ZJPhotoPickerHUD.show(message: nil, inView: naviVc.view, animated: true, needsIndicator: true, hideAfter: TimeInterval.greatestFiniteMagnitude)
        ZJPhotoPickerHelper.queryAlbumList { (albumModels) in
            hud?.hide(animated: false)
            naviVc.albumModels = albumModels
        }
    }
    
    @objc private func dismissNav() {
        navigationController?.dismiss(animated: true, completion: nil)
    }
    
    @objc private func doneButtonClicked() {
        guard let naviVc = navigationController as? ZJPhotoPickerController else { return }
        naviVc.selections = selectedAssetsPointer.pointee
        let hud = ZJPhotoPickerHUD.show(message: nil, inView: view, hideAfter: TimeInterval.greatestFiniteMagnitude)
        let fullScreenSize = UIScreen.main.bounds.width * UIScreen.main.scale
        var size = CGSize(width: fullScreenSize, height: fullScreenSize)
        if isOriginalPointer.pointee == true {
            size = PHImageManagerMaximumSize
        }
        ZJPhotoPickerHelper.images(for: naviVc.selections, size: size) { (images) in
            hud?.hide(animated: false)
            naviVc.willDismissWhenDoneBtnClicked?(images, naviVc.selections)
            naviVc.dismiss(animated: true, completion: nil)
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
        doneButton.setTitle("完成(\(count))", for: .normal)
        if sumOfImageSizePointer.pointee > 0, originalSizeCheck.isSelected {
            self.originalSizeCheck.setTitle(" 原图  \(self.sumOfImageSizePointer.pointee.bytesSize)", for: .normal)
        } else {
            self.originalSizeCheck.setTitle(" 原图 ", for: .normal)
        }
        self.originalSizeCheck.sizeToFit()
        self.originalSizeCheck.center = CGPoint(x: self.view.frame.width/2, y: self.bottomBarHeight/2)
    }
    
    @objc private func previewButtonClicked() {
        
    }
}

extension ZJPhotoPickerThumbnailController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ZJPhotoPickerThumbnailCell.reuseIdentifier, for: indexPath) as! ZJPhotoPickerThumbnailCell
        cell.asset = assets[indexPath.item]
        weak var weakInstance = cell
        cell.imageClicked = { [weak self] asset in
            guard let asset = asset, let `self` = self else { return }
            var selectionChanged = false
            var selectionDeleted = false
            if !asset.isSelected {
                if self.selectedAssetsPointer.pointee.count < self.maxSelectionAllowed {
                    asset.isSelected = true
                    if !self.selectedAssetsPointer.pointee.contains(asset) { // 防止重复添加
                        self.selectedAssetsPointer.pointee.append(asset)
                        asset.selectedOrder = NSNumber(value: self.selectedAssetsPointer.pointee.count)
                        guard let naviVc = self.navigationController as? ZJPhotoPickerController else { return }
                        naviVc.selections = self.selectedAssetsPointer.pointee
                        naviVc.selectionsChanged?(naviVc.selections)
                        ZJPhotoPickerHelper.imageSize(of: [asset], synchronous: true, completion: { (size) in
                            self.sumOfImageSizePointer.pointee += size
                        })
                        selectionChanged = true
                    }
                } else {
                    ZJPhotoPickerHUD.show(message: "不得超过\(self.maxSelectionAllowed)张", inView: self.view, animated: true, needsIndicator: false, hideAfter: 1.2)
                }
            } else {
                asset.isSelected = false
                if var index = self.selectedAssetsPointer.pointee.index(of: asset) {
                    self.selectedAssetsPointer.pointee.remove(at: index)
                    if index < self.selectedAssetsPointer.pointee.count {
                        selectionDeleted = true
                        let startIndex = index
                        for _ in startIndex..<self.selectedAssetsPointer.pointee.count {
                            self.selectedAssetsPointer.pointee[index].selectedOrder = NSNumber(value: index + 1)
                            index += 1
                        }
                    }
                    guard let naviVc = self.navigationController as? ZJPhotoPickerController else { return }
                    naviVc.selections = self.selectedAssetsPointer.pointee
                    naviVc.selectionsChanged?(naviVc.selections)
                    ZJPhotoPickerHelper.imageSize(of: [asset], synchronous: true, completion: { (size) in
                        self.sumOfImageSizePointer.pointee -= size
                        if self.sumOfImageSizePointer.pointee <= 0 {
                            self.sumOfImageSizePointer.pointee = 0
                        }
                    })
                    selectionChanged = true
                }
            }
            weakInstance?.refreshSelectButton(with: asset)
            
            guard selectionChanged else { return }
            self.refreshBottomBar()
            
            if selectionDeleted {
                var relatedCellIndexPathes = [IndexPath]()
                for asset in self.selectedAssetsPointer.pointee {
                    if let index = self.assets.index(of: asset) {
                        let indexPath = IndexPath(item: index, section: 0)
                        relatedCellIndexPathes.append(indexPath)
                    }
                }
                var index = 0
                for indexPath in relatedCellIndexPathes {
                    if let cell = collectionView.cellForItem(at: indexPath) as? ZJPhotoPickerThumbnailCell {
                        cell.refreshSelectButton(with: self.selectedAssetsPointer.pointee[index], animated: false)
                    }
                    index += 1
                }
            }
        }
        return cell
    }
}

class ZJPhotoPickerThumbnailCell: UICollectionViewCell {
    static let reuseIdentifier = "ZJPhotoPickerThumbnailCell"
    fileprivate var imageButton  = UIButton()
    fileprivate var selectButton = UIButton()
    
    var imageClicked: ((PHAsset?) -> Void)?
    
    var asset: PHAsset? {
        didSet {
            guard let asset = asset else { return }
            var imageSize = imageButton.bounds.size
            if imageSize.width < 300 {
                imageSize = CGSize(width: 300, height: 300)
            }
            ZJPhotoPickerHelper.image(for: asset, size: imageSize) { (image, _) in
                self.imageButton.setImage(image, for: .normal)
            }
            refreshSelectButton(with: asset)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(imageButton)
        imageButton.clipsToBounds = true
        imageButton.imageView?.contentMode = .scaleAspectFill
        imageButton.addTarget(self, action: #selector(imageButtonClicked), for: .touchUpInside)
        
        addSubview(selectButton)
        selectButton.titleLabel?.font = UIFont.systemFont(ofSize: 11)
        selectButton.setBackgroundImage(#imageLiteral(resourceName: "btn_unselected"), for: .normal)
        selectButton.setBackgroundImage(#imageLiteral(resourceName: "btn_selected"), for: .selected)
        selectButton.isUserInteractionEnabled = false
        selectButton.sizeToFit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func refreshSelectButton(with asset: PHAsset, animated: Bool = true) {
        selectButton.isSelected = asset.isSelected
        if asset.selectedOrder.intValue > 0 {
            selectButton.setBackgroundImage(#imageLiteral(resourceName: "btn_order"), for: .selected)
            selectButton.setTitle("\(asset.selectedOrder.intValue)", for: .selected)
        } else {
            selectButton.setBackgroundImage(#imageLiteral(resourceName: "btn_unselected"), for: .normal)
            selectButton.setBackgroundImage(#imageLiteral(resourceName: "btn_selected"), for: .selected)
        }
        if asset.isSelected, animated {
            selectButton.layer.add(selectionAnimation, forKey: "")
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageButton.frame = bounds
        let padding: CGFloat = 2
        selectButton.frame = CGRect(x: frame.width - selectButton.bounds.width - padding, y: padding, width: selectButton.bounds.width, height: selectButton.bounds.height)
    }
    
    @objc private func imageButtonClicked() {
        imageClicked?(asset)
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
