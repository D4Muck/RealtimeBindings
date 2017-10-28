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

class ViewController: UIViewController {

    @IBOutlet var tableView: UITableView!
    @IBOutlet var addButton: UIBarButtonItem!

    let disposeBag = DisposeBag()
    static let shoppingItemEndpoint = "http://localhost:8081/shoppingItem"

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        let dataSource = RealtimeDataSource<ShoppingItem>(url: ViewController.shoppingItemEndpoint)

        tableView.observeChangesFrom(
                dataSource: dataSource,
                sortBy: { $1.bought }
        )
        { (tableView: UITableView, row: Int, element: ShoppingItemViewModel) -> UITableViewCell in
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") as! ShoppingItemTableViewCell
            cell.item = element
            return cell
        }.disposed(by: disposeBag)

        addButton.rx.tap.asDriver()
                .flatMapLatest { [weak self] _ -> Driver<String> in
                    guard let me = self else { return Driver.never() }
                    return me.presentAlert().asDriver(onErrorDriveWith: Driver.never())
                }
                .flatMapLatest {
                    return dataSource.saveElement(ShoppingItem(id: "", name: $0, bought: false))
                            .debug()
                            .asDriver(onErrorJustReturn: ())
                }
                .drive().disposed(by: disposeBag)
    }
}

extension UIViewController {

    func presentAlert() -> Single<String> {
        return Single.create { [weak self]  e in
            guard let me = self else {
                e(.error(NSError(domain: "Self already deallocated", code: 101)))
                return Disposables.create()
            }

            let alert = UIAlertController(title: "Add Item", message: nil, preferredStyle: .alert)
            alert.addTextField()

            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                e(.success(alert.textFields?[0].text ?? ""))
            }))

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                e(.error(NSError(domain: "Cancel pressed", code: 102)))
            }))

            me.present(alert, animated: true, completion: nil)

            return Disposables.create {
                alert.dismiss(animated: true, completion: nil)
            }
        }
    }
}

struct ShoppingItemViewModel: ViewModelType {
    let idProperty: Variable<String>
    let name: Variable<String>
    let bought: Variable<Bool>
    private(set) var updatedElements: Observable<ShoppingItem>

    init(fromElement: ShoppingItem) {
        idProperty = Variable(fromElement.id)
        name = Variable(fromElement.name)
        bought = Variable(fromElement.bought)

        updatedElements = Observable.combineLatest(
                idProperty.asObservable().distinctUntilChanged(),
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
    var id: String {
        return idProperty.value
    }
}

extension ShoppingItemViewModel: Equatable {
    static func ==(lhs: ShoppingItemViewModel, rhs: ShoppingItemViewModel) -> Bool {
        return lhs.idProperty.value == rhs.idProperty.value
                && lhs.name.value == rhs.name.value
                && lhs.bought.value == rhs.bought.value
    }
}

struct ShoppingItem: Codable, CustomStringConvertible, IdentifiableType {
    var id: String
    var name: String
    var bought: Bool

    var description: String {
        return "\(name), Schon gekauft: \(bought)"
    }
}

extension ShoppingItem: Equatable {
    static func ==(lhs: ShoppingItem, rhs: ShoppingItem) -> Bool {
        return lhs.id == rhs.id
                && lhs.name == rhs.name
                && lhs.bought == rhs.bought
    }
}

extension ShoppingItem {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ShoppingItem.CodingKeys.self)

        if (!id.isEmpty) {
            try container.encode(id, forKey: .id)
        }
        try container.encode(name, forKey: .name)
        try container.encode(bought, forKey: .bought)
    }
}
