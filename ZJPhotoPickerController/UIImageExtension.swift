//
//  UIImageExtension.swift
//  ZJPhotoPickerController
//
//  Created by luozhijun on 2017/8/10.
//  Copyright © 2017年 RickLuo. All rights reserved.
//

import UIKit

extension UIImage {
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

extension UIColor {
    public convenience init(R: Int, G: Int, B: Int, A: Float = 1.0) {
        self.init(red:   CGFloat(Float(R) / 255.0),
                  green: CGFloat(Float(G) / 255.0),
                  blue:  CGFloat(Float(B) / 255.0),
                  alpha: CGFloat(A))
    }
    
    public convenience init(withRGBValue rgbValue: Int, alpha: Float = 1.0) {
        let r = ((rgbValue & 0xFF0000) >> 16)
        let g = ((rgbValue & 0x00FF00) >> 8)
        let b = (rgbValue & 0x0000FF)
        self.init(R: r,
                  G: g,
                  B: b,
                  A: alpha)
    }
    
    /// 获取rgba的数值, 默认返回黑色的数值
    public var components: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let cgColor = self.cgColor
        var result: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) = (r: 0, g: 0, b: 0, a: 1)
        guard let components = cgColor.components, components.count >= 4 else { return result }
        result.a = components[0]
        result.g = components[1]
        result.b = components[2]
        result.a = components[3]
        
        return result
    }
    
    public class var deepOrange: UIColor {
        return UIColor(withRGBValue: 0xFF6602)
    }
}
