//
//  ManageWatchlistsController.swift
//  Bullish Square
//
//  Created by Javier Gomez on 09/14/26.
//

import UIKit

protocol ManageWatchlistsControllerDelegate: AnyObject {
    ///Fired when the selection changed, or when the active list was renamed or removed, so
    ///the watchlist can reload and retitle itself.
    func manageWatchlistsControllerDidChangeSelection(_ controller: ManageWatchlistsController)
}

///The sheet behind the navigation bar's watchlist icon. Switches between lists, renames them,
///and creates new ones.
///
///Built in code rather than Interface Builder on purpose: this screen has real interaction,
///and hand-written IB XML cannot be checked without opening Xcode.
final class ManageWatchlistsController: UIViewController {

    weak var delegate: ManageWatchlistsControllerDelegate?

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let store = WatchlistStore.shared
    private var watchlists: [WatchlistStore.Watchlist] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(named: "colorPrimary")
        title = "Watchlists"

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(closeTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(addTapped))

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        store.ensureDefaultExists()
        reload()
    }

    private func reload() {
        watchlists = store.allWatchlists()
        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func addTapped() {
        presentNamePrompt(title: "New Watchlist",
                          message: "Give this watchlist a name.",
                          initialName: "",
                          confirmTitle: "Create") { [weak self] name in
            guard let self, let created = self.store.create(name: name) else { return }
            //Switch straight to it. Creating a list and staying on the old one reads as
            //nothing having happened.
            self.store.activeWatchlistID = created.id
            self.reload()
            self.delegate?.manageWatchlistsControllerDidChangeSelection(self)
        }
    }

    private func presentRename(for watchlist: WatchlistStore.Watchlist) {
        presentNamePrompt(title: "Rename Watchlist",
                          message: "Enter a new name for \"\(watchlist.name)\".",
                          initialName: watchlist.name,
                          confirmTitle: "Save") { [weak self] name in
            guard let self else { return }
            self.store.rename(id: watchlist.id, to: name)
            self.reload()
            if watchlist.id == self.store.activeWatchlistID {
                self.delegate?.manageWatchlistsControllerDidChangeSelection(self)
            }
        }
    }

    private func presentDelete(for watchlist: WatchlistStore.Watchlist) {
        let alert = UIAlertController(
            title: "Delete \"\(watchlist.name)\"?",
            message: "This removes the watchlist and every stock in it. It cannot be undone.",
            preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self else { return }
            let wasActive = watchlist.id == self.store.activeWatchlistID
            guard self.store.delete(id: watchlist.id) else { return }
            self.reload()
            if wasActive {
                self.delegate?.manageWatchlistsControllerDidChangeSelection(self)
            }
        })

        present(alert, animated: true)
    }

    ///One prompt for both create and rename, so the two cannot drift apart. The confirm
    ///action stays disabled while the field is empty.
    private func presentNamePrompt(title: String,
                                   message: String,
                                   initialName: String,
                                   confirmTitle: String,
                                   onConfirm: @escaping (String) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = WatchlistStore.defaultWatchlistName
            textField.text = initialName
            textField.autocapitalizationType = .words
            textField.clearButtonMode = .whileEditing
        }

        let confirm = UIAlertAction(title: confirmTitle, style: .default) { [weak alert] _ in
            let name = alert?.textFields?.first?.text ?? ""
            onConfirm(name)
        }
        confirm.isEnabled = !initialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(confirm)

        //Keeps an empty name from being submitted, rather than silently substituting one.
        if let textField = alert.textFields?.first {
            NotificationCenter.default.addObserver(
                forName: UITextField.textDidChangeNotification,
                object: textField,
                queue: .main) { _ in
                    let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    confirm.isEnabled = !text.isEmpty
                }
        }

        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

extension ManageWatchlistsController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        watchlists.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "WatchlistCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "WatchlistCell")

        let watchlist = watchlists[indexPath.row]

        var content = cell.defaultContentConfiguration()
        content.text = watchlist.name
        content.textProperties.color = UIColor(named: "colorSecondary") ?? .label
        cell.contentConfiguration = content

        //A checkmark rather than selection styling: the row stays marked after the sheet
        //closes and reopens.
        cell.accessoryType = watchlist.id == store.activeWatchlistID ? .checkmark : .none
        cell.tintColor = UIColor(named: "colorAccent")
        cell.backgroundColor = UIColor(named: "colorPrimary")

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < watchlists.count else { return }

        store.activeWatchlistID = watchlists[indexPath.row].id
        tableView.reloadData()
        delegate?.manageWatchlistsControllerDidChangeSelection(self)
        dismiss(animated: true)
    }

    ///Rename and delete hang off a swipe. Delete is withheld on the last remaining list
    ///rather than offered and refused.
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row < watchlists.count else { return nil }
        let watchlist = watchlists[indexPath.row]

        let rename = UIContextualAction(style: .normal, title: "Rename") { [weak self] _, _, done in
            self?.presentRename(for: watchlist)
            done(true)
        }
        rename.backgroundColor = UIColor(named: "colorAccent")

        guard watchlists.count > 1 else {
            return UISwipeActionsConfiguration(actions: [rename])
        }

        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
            self?.presentDelete(for: watchlist)
            done(true)
        }

        return UISwipeActionsConfiguration(actions: [delete, rename])
    }
}
