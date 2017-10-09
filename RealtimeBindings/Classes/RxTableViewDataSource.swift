//
// Created by Christoph Muck on 09/10/2017.
//

import Foundation
import RxCocoa
import RxSwift

class RxTableViewReactiveArrayDataSource<S: Sequence>:
        NSObject,
        UITableViewDataSource,
        SectionedViewDataSourceType,
        RxTableViewDataSourceType {

    typealias Element = S
    typealias SequenceItem = S.Iterator.Element

    typealias CellFactory = (UITableView, Int, SequenceItem) -> UITableViewCell

    var itemModels: [SequenceItem]? = nil

    func tableView(_ tableView: UITableView, observedEvent: Event<Element>) {
        Binder(self) { tableViewDataSource, sectionModels in
            let sections = Array(sectionModels)
            tableViewDataSource.tableView(tableView, observedElements: sections)
        }.on(observedEvent)
    }

    func modelAtIndex(_ index: Int) -> SequenceItem? {
        return itemModels?[index]
    }

    func model(at indexPath: IndexPath) throws -> Any {
        precondition(indexPath.section == 0)
        guard let item = itemModels?[indexPath.item] else {
            throw RxCocoaError.itemsNotYetBound(object: self)
        }
        return item
    }

    let cellFactory: CellFactory

    init(cellFactory: @escaping CellFactory) {
        self.cellFactory = cellFactory
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return itemModels?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cellFactory(tableView, indexPath.item, itemModels![indexPath.row])
    }

    // reactive

    func tableView(_ tableView: UITableView, observedElements: [SequenceItem]) {
        self.itemModels = observedElements

        tableView.reloadData()
    }
}