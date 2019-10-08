//
//  TextCell.swift
//  tencent-broadcast
//
//  Created by 松澤 友弘 on 2019/10/08.
//  Copyright © 2019 CyberAgent. All rights reserved.
//

import UIKit

class TextCell: UICollectionViewCell {
    var label: UILabel!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static let reuseIdentifier: String = NSStringFromClass(TextCell.self)

    override var isSelected: Bool {
        didSet {
            if self.isSelected {
                label.textColor = UIColor(red: 10/255.0, green: 204/255.0, blue: 172/255.0, alpha: 1.0)
            } else {
                label.textColor = UIColor.white
        }
      }
    }

    private func setupView() {
        layer.borderColor = UIColor.white.cgColor
        label = UILabel(frame: bounds)
        label.textColor = UIColor.white
        label.textAlignment = .center
        addSubview(label)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds
    }
}
