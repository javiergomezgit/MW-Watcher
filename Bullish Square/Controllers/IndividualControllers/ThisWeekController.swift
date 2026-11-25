//
//  ThisWeekController.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/25/26.
//

import UIKit

///"This week on your watchlists" (BS-317): the Friday email's weekly section, any day of the
///week, reached by tapping the changes line above the watchlist. Every stock on every list, as
///the email has them. The server words each line, so the two always say the same thing.
///
///Display only: states with their dates, never what to do about them. A changed stock opens its
///Health card.
final class ThisWeekController: UIViewController {

    private enum Row {
        case change(WeeklyReport.Change)
        case grouped(String)
        case market(WeeklyReport.Market)
    }

    private struct Section {
        let title: String?
        let rows: [Row]
        let footer: String?
    }

    ///Every stock on the person's lists, without repeats.
    private let tickers: [String]
    ///How many lists those came from. The line that opens this screen is about one list, so
    ///the screen says it covers them all.
    private let listCount: Int
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var sections: [Section] = []
    ///Bumped by each load, so an older answer arriving late is ignored.
    private var loadID = 0

    init(tickers: [String], listCount: Int) {
        var seen = Set<String>()
        self.tickers = tickers.map { $0.uppercased() }.filter { !$0.isEmpty && seen.insert($0).inserted }
        self.listCount = listCount
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("ThisWeekController is built in code")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "This Week"
        view.backgroundColor = UIColor(named: "colorPrimary")

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "row")
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        load()
    }

    // MARK: - Loading

    private func load() {
        guard !tickers.isEmpty else {
            var empty = UIContentUnavailableConfiguration.empty()
            empty.image = UIImage(systemName: "list.bullet")
            empty.text = "No Stocks Yet"
            empty.secondaryText = "Add stocks to a watchlist and their week shows here."
            contentUnavailableConfiguration = empty
            return
        }
        loadID += 1
        let id = loadID
        var loading = UIContentUnavailableConfiguration.loading()
        loading.text = "Checking this week…"
        contentUnavailableConfiguration = loading

        StockAPI.shared.getThisWeek(tickers: tickers) { [weak self] result in
            guard let self, id == self.loadID else { return }
            switch result {
            case .success(let report):
                self.contentUnavailableConfiguration = nil
                self.show(report)
            case .failure:
                self.showUnavailable()
            }
        }
    }

    ///Said plainly, with a way to ask again, rather than an empty screen.
    private func showUnavailable() {
        sections = []
        tableView.reloadData()
        var unavailable = UIContentUnavailableConfiguration.empty()
        unavailable.image = UIImage(systemName: "wifi.exclamationmark")
        unavailable.text = "This Week Can't Be Checked Right Now"
        unavailable.secondaryText = "The price service didn't answer. Prices on the watchlist still update."
        var retry = UIButton.Configuration.filled()
        retry.title = "Try Again"
        unavailable.button = retry
        unavailable.buttonProperties.primaryAction = UIAction { [weak self] _ in self?.load() }
        contentUnavailableConfiguration = unavailable
    }

    private func show(_ report: WeeklyReport) {
        let stocks = "\(tickers.count) stock\(tickers.count == 1 ? "" : "s")"
        let scope = listCount > 1 ? "On all \(listCount) watchlists · \(stocks)" : "On your watchlist · \(stocks)"
        let weekOf = "\(scope)\nWeek of \(StockHealthFormat.day(report.weekStart)) · as of \(StockHealthFormat.day(report.day)) close"
        var changeRows = report.changes.map { Row.change($0) }
        if changeRows.isEmpty {
            changeRows = [.grouped("Nothing changed this week.")]
        }
        var groupedRows: [Row] = []
        if !report.unchanged.isEmpty {
            groupedRows.append(.grouped("No change detected: \(report.unchanged.joined(separator: ", "))"))
        }
        if !report.noHealth.isEmpty {
            groupedRows.append(.grouped("Not enough history yet: \(report.noHealth.joined(separator: ", "))"))
        }
        let cut = tickers.count > StockAPI.thisWeekMaxSymbols
            ? "Showing the first \(StockAPI.thisWeekMaxSymbols) of your \(tickers.count) stocks."
            : nil

        sections = [Section(title: weekOf, rows: changeRows, footer: groupedRows.isEmpty ? cut : nil)]
        if !groupedRows.isEmpty {
            sections.append(Section(title: nil, rows: groupedRows, footer: cut))
        }
        if let market = report.market {
            sections.append(Section(title: "Market", rows: [.market(market)],
                                    footer: "States, not advice. The market line is context, never a signal."))
        }
        tableView.reloadData()
    }
}

// MARK: - Table

extension ThisWeekController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section].footer
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
        var content = UIListContentConfiguration.subtitleCell()
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.numberOfLines = 0
        content.secondaryTextProperties.color = .secondaryLabel
        cell.accessoryType = .none
        cell.selectionStyle = .none

        switch sections[indexPath.section].rows[indexPath.row] {
        case .change(let change):
            let line = NSMutableAttributedString(string: change.symbol + "  ",
                                                 attributes: [.font: UIFont.preferredFont(forTextStyle: .headline)])
            line.append(NSAttributedString(string: change.headline,
                                           attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]))
            content.attributedText = line
            content.secondaryText = change.detail
            content.image = UIImage(systemName: StockHealthFormat.symbolName(for: change.label))
            content.imageProperties.tintColor = StockHealthFormat.color(for: change.label)
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
            cell.accessibilityLabel = "\(change.symbol), \(change.headline), \(change.detail), now \(StockHealthFormat.title(for: change.label))"
            cell.accessibilityHint = "Opens its Health card"
        case .grouped(let text):
            content.text = text
            content.textProperties.color = .secondaryLabel
            cell.accessibilityLabel = text
            cell.accessibilityHint = nil
        case .market(let market):
            content.text = market.line
            content.image = UIImage(systemName: "chart.line.uptrend.xyaxis")
            content.imageProperties.tintColor = .secondaryLabel
            cell.accessibilityLabel = "Market: \(market.line)"
            cell.accessibilityHint = nil
        }
        cell.contentConfiguration = content
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        //Read at tap time from the current sections, never from a captured row.
        guard indexPath.section < sections.count, indexPath.row < sections[indexPath.section].rows.count,
              case .change(let change) = sections[indexPath.section].rows[indexPath.row],
              let chart = ChartController.healthChart(symbol: change.symbol) else {
            return
        }
        navigationController?.pushViewController(chart, animated: true)
    }
}
