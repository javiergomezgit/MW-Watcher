//
//  SpinnerViewController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 4/17/22.
//

import Foundation
import UIKit

class Spinner: UIViewController {
    var spinner = UIActivityIndicatorView(style: .large)

    override func loadView() {
        view = UIView()
        view.backgroundColor = .label.withAlphaComponent(0.6)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        spinner.color = .systemBackground
        view.addSubview(spinner)

        spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }
}
