//
//  ViewController.swift
//  RealtimeBindings
//
//  Created by Christoph Muck on 10/01/2017.
//  Copyright (c) 2017 Christoph Muck. All rights reserved.
//

import UIKit
import RealtimeBindings
import RxCocoa
import RxSwift
import RxDataSources

class ViewController: UIViewController {

    @IBOutlet var tableView: UITableView!

    let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        tableView.observeChangesFrom(url: "http://localhost:8081/shoppingItem/changes"
                , sortBy: { $1.bought.value }
        )
        { (tableView: UITableView, row: Int, element: ShoppingItemViewModel) -> UITableViewCell in
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") as! ShoppingItemTableViewCell
            cell.item = element
            return cell
        }.disposed(by: disposeBag)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}


struct ShoppingItemViewModel: ViewModelType {

    let id: Variable<String>
    let name: Variable<String>
    let bought: Variable<Bool>
    private(set) var updatedElements: Observable<ShoppingItem>

    init(fromElement: ShoppingItem) {
        id = Variable(fromElement.id)
        name = Variable(fromElement.name)
        bought = Variable(fromElement.bought)

        updatedElements = Observable.combineLatest(
                id.asObservable().distinctUntilChanged(),
                name.asObservable().distinctUntilChanged(),
                bought.asObservable().distinctUntilChanged()
        ) { (id, name, bought) in ShoppingItem(id: id, name: name, bought: bought) }.skip(1)
    }
}

extension ShoppingItemViewModel: CustomStringConvertible {

    var description: String {
        return name.value
    }
}

extension ShoppingItemViewModel: IdentifiableType {

    var identity: String {
        return id.value
    }
}

extension ShoppingItemViewModel: Equatable {
    static func ==(lhs: ShoppingItemViewModel, rhs: ShoppingItemViewModel) -> Bool {
        return lhs.id == rhs.id
                && lhs.name == rhs.name
                && lhs.bought == rhs.bought
    }
}

struct ShoppingItem: Codable, CustomStringConvertible, IdentifiableType {
    var id: String
    var name: String
    var bought: Bool

    var description: String {
        return "\(name), Schon gekauft: \(bought)"
    }

    var identity: String {
        return id
    }
}

extension ShoppingItem: Equatable {
    static func ==(lhs: ShoppingItem, rhs: ShoppingItem) -> Bool {
        return lhs.id == rhs.id
                && lhs.name == rhs.name
                && lhs.bought == rhs.bought
    }
}

