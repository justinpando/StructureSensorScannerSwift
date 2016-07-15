/*
  This file is part of the Structure SDK.
  Copyright © 2015 Occipital, Inc. All rights reserved.
  http://structure.io
*/
// Predefined colors used in the app.
//let redButtonColorWithAlpha: UIColor
//
//let blueButtonColorWithAlpha: UIColor
//
//let blueGrayButtonColorWithAlpha: UIColor
//
//let redButtonColorWithLightAlpha: UIColor
//
//let blackLabelColorWithLightAlpha: UIColor

let redButtonColorWithAlpha: UIColor = UIColor(red: 230.0 / 255, green: 72.0 / 255, blue: 64.0 / 255, alpha: 0.85)

let blueButtonColorWithAlpha: UIColor = UIColor(red: 0.160784314, green: 0.670588235, blue: 0.88627451, alpha: 0.85)

let blueGrayButtonColorWithAlpha: UIColor = UIColor(red: 64.0 / 255, green: 110.0 / 255, blue: 117.0 / 255, alpha: 0.85)

let redButtonColorWithLightAlpha: UIColor = UIColor(red: 230.0 / 255, green: 72.0 / 255, blue: 64.0 / 255, alpha: 0.45)

let blackLabelColorWithLightAlpha: UIColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.2)

extension UIButton {
    func applyCustomStyleWithBackgroundColor(color: UIColor) {
        self.layer.cornerRadius = 15.0
        self.backgroundColor = color
        self.titleLabel?.textColor = UIColor.whiteColor()
        self.layer.borderColor = UIColor.whiteColor().CGColor
        self.layer.borderWidth = 2.0
        self.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        self.setTitleColor(UIColor.whiteColor(), forState: .Selected)
        self.setTitleColor(UIColor.whiteColor(), forState: .Highlighted)
        self.titleLabel?.font = UIFont(name: "Helvetica Neue", size: 16.0)
    }
}
extension UILabel {
    func applyCustomStyleWithBackgroundColor(color: UIColor) {
        self.layer.cornerRadius = 15.0
        self.backgroundColor = color
        self.textColor = UIColor.whiteColor()
        self.layer.masksToBounds = true
    }
}


