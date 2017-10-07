//
// Created by Christoph Muck on 06/10/2017.
// Copyright (c) 2017 CocoaPods. All rights reserved.
//

import RxCocoa
import RxSwift
import M13Checkbox

extension Reactive where Base: M13Checkbox {

    /// Reactive wrapper for `checkState` property.
    public var checkState: ControlProperty<Bool> {
        return value
    }

    public var value: ControlProperty<Bool> {
        return UIControl.valuePublic(
                self.base,
                getter: { checkbox in
                    switch checkbox.checkState {
                    case .checked: return true
                    case .unchecked: return false
                    case .mixed: return false
                    }
                }, setter: { checkbox, checked in
            checkbox.checkState = checked ? .checked : .unchecked
        }
        )
    }
}

extension UIControl {
     static func valuePublic<T, ControlType: UIControl>(_ control: ControlType, getter:  @escaping (ControlType) -> T, setter: @escaping (ControlType, T) -> ()) -> ControlProperty<T> {
        let values: Observable<T> = Observable.deferred { [weak control] in
            guard let existingSelf = control else {
                return Observable.empty()
            }

            return (existingSelf as UIControl).rx.controlEvent([.allEditingEvents, .valueChanged])
                .flatMap { _ in
                    return control.map { Observable.just(getter($0)) } ?? Observable.empty()
                }
                .startWith(getter(existingSelf))
        }
        return ControlProperty(values: values, valueSink: Binder(control) { control, value in
            setter(control, value)
        })
    }
}
