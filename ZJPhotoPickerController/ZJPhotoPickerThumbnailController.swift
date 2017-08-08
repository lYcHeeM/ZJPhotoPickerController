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
    fileprivate var collectionView: UICollectionView!
    fileprivate var maxSelectionAllowed = 9
    fileprivate var selectedAssetsPointer: UnsafeMutablePointer<[PHAsset]>!
    
    required init(assetsModel: [PHAsset], maxSelectionAllowed: Int = 9, selectedAssetsPointer: UnsafeMutablePointer<[PHAsset]>) {
        super.init(nibName: nil, bundle: nil)
        assets = assetsModel
        self.selectedAssetsPointer = selectedAssetsPointer
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
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
        let done   = UIBarButtonItem(title: "完成", style: .plain, target: self, action: #selector(doneButtonClicked))
        navigationItem.rightBarButtonItems = [cancel, done]
        
        let flowLayout = UICollectionViewFlowLayout()
        let pixel = 1/UIScreen.main.scale
        let itemCountInOneLine = 4
        flowLayout.minimumInteritemSpacing = 2*pixel
        flowLayout.minimumLineSpacing = 2*pixel
        let itemSize = (view.frame.width - CGFloat(itemCountInOneLine - 1) * flowLayout.minimumInteritemSpacing) / CGFloat(itemCountInOneLine)
        flowLayout.itemSize = CGSize(width: itemSize, height: itemSize)
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: flowLayout)
        collectionView.backgroundColor = view.backgroundColor
        collectionView.register(ZJPhotoPickerThumbnailCell.self, forCellWithReuseIdentifier: ZJPhotoPickerThumbnailCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate   = self
        collectionView.scrollToItem(at: IndexPath(item: assets.count - 1, section: 0), at: .bottom, animated: false)
        view.addSubview(collectionView)
    }
    
    @objc private func back() {
        guard let naviVc = navigationController as? ZJPhotoPickerController else { return }
        naviVc.selections = selectedAssetsPointer.pointee
        naviVc.selectionsFinished?(selectedAssetsPointer.pointee)
        naviVc.popViewController(animated: true)
    }
    
    @objc private func doneButtonClicked() {
        guard let naviVc = navigationController as? ZJPhotoPickerController else { return }
        naviVc.selections = selectedAssetsPointer.pointee
        naviVc.willDismissWhenDoneBtnClicked?(selectedAssetsPointer.pointee)
        naviVc.dismiss(animated: true, completion: nil)
    }
    
    @objc private func dismissNav() {
        navigationController?.dismiss(animated: true, completion: nil)
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
            if !asset.isSelected {
                if self.selectedAssetsPointer.pointee.count < self.maxSelectionAllowed {
                    asset.isSelected = true
                    weakInstance?.selectButton.isSelected = true
                    if !self.selectedAssetsPointer.pointee.contains(asset) { // 防止重复添加
                        self.selectedAssetsPointer.pointee.append(asset)
                        guard let naviVc = self.navigationController as? ZJPhotoPickerController else { return }
                        naviVc.selections = self.selectedAssetsPointer.pointee
                        naviVc.selectionsChanged?(naviVc.selections)
                    }
                } else {
                    ZJPhotoPickerHUD.show(message: "不得超过\(self.maxSelectionAllowed)张", inView: self.view, animated: true, needsIndicator: false, hideAfter: 1.2)
                }
            } else {
                asset.isSelected = false
                weakInstance?.selectButton.isSelected = false
                if let index = self.selectedAssetsPointer.pointee.index(of: asset) {
                    self.selectedAssetsPointer.pointee.remove(at: index)
                    guard let naviVc = self.navigationController as? ZJPhotoPickerController else { return }
                    naviVc.selections = self.selectedAssetsPointer.pointee
                    naviVc.selectionsChanged?(naviVc.selections)
                }
            }
        }
        return cell
    }
}

class ZJPhotoPickerThumbnailCell: UICollectionViewCell {
    static let reuseIdentifier = "ZJPhotoPickerThumbnailCell"
    fileprivate var imageButton = UIButton()
    fileprivate var selectButton = UIButton()
    
    var imageClicked: ((PHAsset?) -> Void)?
    
    var asset: PHAsset? {
        didSet {
            guard let asset = asset else { return }
            var imageSize = imageButton.bounds.size
            if imageSize.width < 200 {
                imageSize = CGSize(width: 200, height: 200)
            }
            ZJPhotoPickerHelper.image(for: asset, size: imageSize) { (image, _) in
                self.imageButton.setImage(image, for: .normal)
            }
            selectButton.isSelected = asset.isSelected
            selectButton.layer.add(selectionAnimation, forKey: "")
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(imageButton)
        imageButton.clipsToBounds = true
        imageButton.imageView?.contentMode = .scaleAspectFill
        imageButton.addTarget(self, action: #selector(imageButtonClicked), for: .touchUpInside)
        
        addSubview(selectButton)
        selectButton.setImage(#imageLiteral(resourceName: "btn_unselected"), for: .normal)
        selectButton.setImage(#imageLiteral(resourceName: "btn_selected"), for: .selected)
        selectButton.isUserInteractionEnabled = false
        selectButton.sizeToFit()
    }
    
    @objc private func imageButtonClicked() {
        imageClicked?(asset)
        if selectButton.isSelected {
            selectButton.layer.add(selectionAnimation, forKey: "")
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageButton.frame = bounds
        let padding: CGFloat = 2
        selectButton.frame = CGRect(x: frame.width - selectButton.bounds.width - padding, y: padding, width: selectButton.bounds.width, height: selectButton.bounds.height)
    }
    
    private var selectionAnimation: CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.duration = 0.2
        animation.isRemovedOnCompletion = true
        animation.fillMode = kCAFillModeForwards
        animation.values = [
            NSValue(caTransform3D: CATransform3DMakeScale(0.8, 0.8, 1.0)),
            NSValue(caTransform3D: CATransform3DMakeScale(1.2, 1.2, 1.0)),
            NSValue(caTransform3D: CATransform3DMakeScale(0.8, 0.8, 1.0)),
            NSValue(caTransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0))
        ]
        return animation
    }
}
