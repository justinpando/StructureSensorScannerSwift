/*
  This file is part of the Structure SDK.
  Copyright © 2015 Occipital, Inc. All rights reserved.
  http://structure.io
*/
import UIKit
class CalibrationOverlay: UIView {
    

    static let padding: CGFloat = 4.0
    static let roundness: CGFloat = 8.0
    static let imageSize: CGFloat = 48.0
    static let fontSize: CGFloat = 16.0
    static let textMargin: CGFloat = 8
    static let textHeight: CGFloat = (imageSize - padding) / 2
    static let textWidth: CGFloat = 280.0 - textMargin
    static let textX: CGFloat = imageSize + 2 * padding + textMargin
    static let totalWidth: CGFloat = padding * 3 + imageSize + textMargin + textWidth
    static let totalHeight: CGFloat = padding * 2 + imageSize
    let messageFrame: CGRect = CGRectMake(textX, padding, textWidth, textHeight)
    let buttonFrame: CGRect = CGRectMake(textX, padding + textHeight + padding, textWidth, textHeight)
    let imageFrame: CGRect = CGRectMake(padding, padding, imageSize, imageSize)

    
    class func calibrationOverlaySubviewOf(view: UIView, atOrigin origin: CGPoint) -> CalibrationOverlay {
        let ret: CalibrationOverlay = CalibrationOverlay(frame: CGRectMake(0, 0, totalWidth, totalHeight))
        view.addSubview(ret)
        ret.frame = CGRectMake(origin.x, origin.y, ret.frame.size.width, ret.frame.size.height)
        return ret
    }

    class func calibrationOverlaySubviewOf(view: UIView, atCenter center: CGPoint) -> CalibrationOverlay {
        let ret: CalibrationOverlay = CalibrationOverlay(frame: CGRectMake(0, 0, totalWidth, totalHeight))
        view.addSubview(ret)
        ret.center = center
        return ret
    }
    var message: UILabel
    var button: UIButton
    var image: UIImageView


    convenience override init(frame: CGRect) {
        self.init(frame: frame)
        self.setup()
    }

    required init?(coder: NSCoder) {
        message = UILabel(frame: messageFrame)
        button = UIButton(type: .System)
        image = UIImageView(frame: imageFrame)
        super.init(coder: coder)
        self.setup()
    }

    func setup() {
        let font: UIFont = UIFont(name: "DIN Alternate Bold", size: CalibrationOverlay.fontSize)!
        self.frame = CGRectMake(0.0, 0.0, CalibrationOverlay.totalWidth, CalibrationOverlay.totalHeight)
        self.backgroundColor = UIColor(white: 0.25, alpha: 0.25)
        self.layer.cornerRadius = CalibrationOverlay.roundness
        self.userInteractionEnabled = true
        image = UIImageView(frame: imageFrame)
        image.contentMode = .ScaleAspectFit
        image.image = UIImage(named: "calibration")
        image.layer.cornerRadius = CalibrationOverlay.roundness
        image.clipsToBounds = true
        self.addSubview(image)
        message = UILabel(frame: messageFrame)
        message.font = font
        message.text = "Calibration needed for best results."
        message.textColor = UIColor.whiteColor()
        self.addSubview(message)
        button = UIButton(type: .System)
        button.frame = buttonFrame
        button.setTitle("Calibrate Now", forState: .Normal)
        button.tintColor = UIColor(red: 0.25, green: 0.73, blue: 0.88, alpha: 1.0)
        button.titleLabel!.font = font
        button.contentHorizontalAlignment = .Left
        button.contentEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 0)
        button.addTarget(self, action: #selector(CalibrationOverlay.buttonClicked(_:)), forControlEvents: .TouchUpInside)
        self.addSubview(button)
    }

    func buttonClicked(button: UIButton) {
        STSensorController.launchCalibratorAppOrGoToAppStore()
    }
}
/*
  This file is part of the Structure SDK.
  Copyright © 2015 Occipital, Inc. All rights reserved.
  http://structure.io
*/


