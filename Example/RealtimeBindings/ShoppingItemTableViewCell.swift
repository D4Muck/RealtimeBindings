//
//  ShoppingItemTableViewCell.swift
//  RealtimeBindings_Example
//
//  Created by Christoph Muck on 06/10/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import UIKit
import M13Checkbox
import RxCocoa
import RxSwift

class ShoppingItemTableViewCell: UITableViewCell {

    @IBOutlet var label: UILabel!
    @IBOutlet var checkbox: M13Checkbox!

    var disposeBag: DisposeBag!

    var item: ShoppingItemViewModel! {
        didSet {
            disposeBag = DisposeBag()

            item.name.asDriver().drive(label.rx.text).disposed(by: disposeBag)

            let bought = item.bought.asDriver()
            bought.drive(checkbox.rx.checkState).disposed(by: disposeBag)

            bought.drive(onNext: { [weak self] bought in
                self?.backgroundColor = bought ? UIColor.lightGray : nil
            }).disposed(by: disposeBag)

            checkbox.rx.checkState.asDriver().skip(1).drive(item.bought).disposed(by: disposeBag)
        }
    }
}
