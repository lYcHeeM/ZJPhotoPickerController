//
//  UIImageExtension.swift
//  ZJPhotoPickerController
//
//  Created by luozhijun on 2017/8/10.
//  Copyright © 2017年 RickLuo. All rights reserved.
//

import UIKit

internal extension UIImage {
    /// 用颜色创建一张图片
    convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContext(rect.size)
        let context:CGContext = UIGraphicsGetCurrentContext()!
        context.setFillColor(color.cgColor)
        context.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }
    
    /// 返回一张可拉伸的图片, 参数分别是图片宽度的一半和图片高度的一半
    var stretchable: UIImage {
        return self.stretchableImage(withLeftCapWidth: Int(self.size.width/2.0), topCapHeight: Int(self.size.height/2.0))
    }
}

public extension UIColor {
    public class var deepOrange: UIColor {
        return UIColor(colorLiteralRed: 255/255, green: 102/255, blue: 2/255, alpha: 1.0)
    }
}
