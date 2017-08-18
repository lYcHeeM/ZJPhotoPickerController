//
//  ViewController.swift
//  ZJPhotoPickerController
//
//  Created by luozhijun on 2017/8/8.
//  Copyright © 2017年 RickLuo. All rights reserved.
//

import UIKit
import Photos

class ViewController: UIViewController {

    var collectionView: UICollectionView!
    var selectedImages = [UIImage]() {
        didSet {
            self.collectionView.reloadData()
        }
    }
    @IBOutlet var separator: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print(Double.greatestFiniteMagnitude)
        setupUI()
    }
    
    func setupUI() {
        let flowLayout = UICollectionViewFlowLayout()
        let itemCountInOneLine = 4
        flowLayout.minimumInteritemSpacing = 3
        flowLayout.minimumLineSpacing = 3
        let itemSize = (view.frame.width - CGFloat(itemCountInOneLine - 1) * flowLayout.minimumInteritemSpacing) / CGFloat(itemCountInOneLine)
        flowLayout.itemSize = CGSize(width: itemSize, height: itemSize)
        collectionView = UICollectionView(frame: CGRect(x: 0, y: separator.frame.maxY, width: view.frame.width, height: view.frame.height - separator.frame.maxY), collectionViewLayout: flowLayout)
        collectionView.backgroundColor = view.backgroundColor
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.dataSource = self
        collectionView.delegate   = self
        view.addSubview(collectionView)
    }

    @IBAction func showPicker(_ sender: Any) {
        let config = ZJPhotoPickerConfiguration.default
        let pickerVc = ZJPhotoPickerController(configuration: config)
        pickerVc.presented(from: self, animated: true, completion: nil, imageQueryFinished: nil)
        pickerVc.didDismissWhenDoneBtnClicked = { images, assets in
            self.selectedImages.append(contentsOf: images)
        }
    }
}

extension ViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return selectedImages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        cell.layer.masksToBounds   = true
        cell.layer.contentsScale   = UIScreen.main.scale
        cell.layer.contents        = selectedImages[indexPath.row].cgImage
        cell.layer.contentsGravity = "resizeAspectFill"
        return cell
    }
}

