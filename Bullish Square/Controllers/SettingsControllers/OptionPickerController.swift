//
//  OptionPickerController.swift
//  Bullish Square
//

import UIKit

///A checklist for one profile choice: Experience picks one and saves on the tap, Interests
///picks several and saves with Save. The caller saves; it answers with an error message or
///nil, as FieldEditController's callers do. (BS-259)
final class OptionPickerController: UITableViewController {

    // MARK: - Properties

    struct Option {
        var id: String
        var title: String
        var detail: String?
    }

    ///The chosen ids, in the options' order.
    var onSave: (([String], @escaping (String?) -> Void) -> Void)?

    private let options: [Option]
    private let allowsMultiple: Bool
    private let footer: String?
    private var selected: Set<String>
    private let initial: Set<String>

    init(title: String, options: [Option], selected: [String], allowsMultiple: Bool, footer: String? = nil) {
        self.options = options
        self.allowsMultiple = allowsMultiple
        self.footer = footer
        self.selected = Set(selected)
        self.initial = Set(selected)
        super.init(style: .insetGrouped)
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        ProfileStyle.style(tableView)
        if allowsMultiple {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))
        }
    }

    // MARK: - Table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        options.count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        footer
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        ProfileStyle.style(headerFooter: view)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let option = options[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        var content = UIListContentConfiguration.subtitleCell()
        content.text = option.title
        content.secondaryText = option.detail
        ProfileStyle.style(&content)
        cell.contentConfiguration = content
        ProfileStyle.style(cell)
        cell.accessoryType = selected.contains(option.id) ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let id = options[indexPath.row].id
        if allowsMultiple {
            if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
            tableView.reloadRows(at: [indexPath], with: .none)
        } else {
            selected = [id]
            tableView.reloadData()
            saveTapped()
        }
    }

    // MARK: - Saving

    @objc private func saveTapped() {
        guard selected != initial else {
            navigationController?.popViewController(animated: true)
            return
        }
        guard let onSave else { return }
        let chosen = options.map(\.id).filter(selected.contains)
        view.isUserInteractionEnabled = false
        navigationItem.rightBarButtonItem?.isEnabled = false
        onSave(chosen) { [weak self] problem in
            DispatchQueue.main.async {
                guard let self else { return }
                self.view.isUserInteractionEnabled = true
                self.navigationItem.rightBarButtonItem?.isEnabled = true
                if let problem {
                    Utilities.showAlert(on: self, title: "Can't Save", message: problem)
                } else {
                    self.navigationController?.popViewController(animated: true)
                }
            }
        }
    }
}
