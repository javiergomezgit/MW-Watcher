//
//  NotificationSettingsController.swift
//  Bullish Square
//

import UIKit

///Settings → Notifications: which Community activity sends a push notification (BS-290), and
///the trend alerts for watchlist stocks (BS-314).
///
///The switches are saved to the account, so they follow the person to another phone and the
///server reads them before sending. When iOS has notifications off for the app, a row says so
///and opens iOS Settings, as the switches alone would change nothing.
final class NotificationSettingsController: UITableViewController {

    // MARK: - Properties

    private enum Section: Int, CaseIterable {
        case system, kinds, trends

        var kinds: [PushNotifications.Kind] {
            switch self {
            case .system: return []
            case .kinds: return PushNotifications.Kind.community
            case .trends: return PushNotifications.Kind.trends
            }
        }
    }

    private var preferences: [PushNotifications.Kind: Bool] = [:]
    ///nil until known; false when iOS has notifications off for the app.
    private var allowed: Bool?
    private let push = PushNotifications.shared

    init() {
        super.init(style: .insetGrouped)
        title = "Notifications"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        ProfileStyle.style(navigationController)
        ProfileStyle.style(tableView)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshAllowed),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
        push.preferences { [weak self] preferences in
            self?.preferences = preferences
            self?.tableView.reloadData()
        }
        refreshAllowed()
    }

    ///Again on return from iOS Settings, where the person may have turned them on.
    @objc private func refreshAllowed() {
        push.isAllowed { [weak self] allowed in
            guard let self else { return }
            self.allowed = allowed
            self.tableView.reloadData()
            //Never asked yet: opening this screen is a good moment.
            if allowed == nil { self.push.askIfNeeded() }
        }
    }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .system: return allowed == false ? 1 : 0
        case .kinds, .trends: return Section(rawValue: section)?.kinds.count ?? 0
        case nil: return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .kinds: return "Community"
        case .trends: return "Watchlist"
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .kinds:
            return "Notifications for activity on your posts and profile in Community."
        case .trends:
            return "When a stock on your watchlists closes more than 2% past its 200-day average, twice in a row. "
                + "At most one per stock every two weeks and three a day, never between 10 pm and 7 am. "
                + "Mute a stock from its Health card."
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        ProfileStyle.style(cell)
        var content = cell.defaultContentConfiguration()
        ProfileStyle.style(&content)

        if Section(rawValue: indexPath.section) == .system {
            content.text = "Notifications Are Off"
            content.secondaryText = "Turn them on for Bullish Square in iOS Settings."
            content.image = UIImage(systemName: "bell.slash")
            cell.accessoryType = .disclosureIndicator
            cell.contentConfiguration = content
            return cell
        }

        guard let kinds = Section(rawValue: indexPath.section)?.kinds, indexPath.row < kinds.count else { return cell }
        let kind = kinds[indexPath.row]
        content.text = kind.title
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        let toggle = UISwitch()
        toggle.isOn = preferences[kind] ?? kind.defaultOn
        toggle.isEnabled = allowed != false
        toggle.addAction(UIAction { [weak self, weak toggle] _ in
            guard let self, let toggle else { return }
            self.changed(kind, on: toggle.isOn, toggle: toggle)
        }, for: .valueChanged)
        cell.accessoryView = toggle
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard Section(rawValue: indexPath.section) == .system,
              let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Saving

    ///Shown at once; put back if the save fails.
    private func changed(_ kind: PushNotifications.Kind, on: Bool, toggle: UISwitch) {
        preferences[kind] = on
        push.setPreference(kind, on: on) { [weak self, weak toggle] error in
            guard let self, error != nil else { return }
            self.preferences[kind] = !on
            toggle?.setOn(!on, animated: true)
            Utilities.showAlert(on: self, title: "Can't Save", message: "Check your connection and try again.")
        }
    }
}
