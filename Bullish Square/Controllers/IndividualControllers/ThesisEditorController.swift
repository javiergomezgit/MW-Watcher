//
//  ThesisEditorController.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/25/26.
//

import UIKit

///"Why are you watching it?" (BS-318). Shown as a sheet right after a stock is added, with Skip
///(Javier's decision, 23 Nov 2026), and from the Thesis card to write or edit one later.
///Skipping never undoes the add: decoration never gates navigation.
///
///The reasons and conditions are the person's own; the app states what happened against them
///and never says what to do.
final class ThesisEditorController: UIViewController {

    private enum Section: Int, CaseIterable {
        case reason, note, reconsider, exitPlan
    }

    ///The exit plan's rows (BS-320): only the goal until one is chosen.
    private enum ExitRow {
        case goal, targetMonth, monthsBefore, why
    }

    private enum ReconsiderRow: Int, CaseIterable {
        case trendBreak, belowStart, belowHigh, business
    }

    ///Hears the saved thesis; nil when skipped or cancelled.
    var onFinish: ((Thesis?) -> Void)?

    private let ticker: String
    private let watchlistID: String
    ///Set when editing; a new thesis gets its starting close when the sheet opens.
    private var thesis: Thesis?
    private var reason: ThesisReason?
    private var note: String
    private var trendBreak: Bool
    private var belowStart: Double?
    private var belowHigh: Double?
    ///nil: no exit plan. `exitNoDate` is "Other, no date".
    private var exitGoal: ExitGoal?
    private var exitNoDate: Bool
    private var exitTargetMonth: String
    private var exitMonthsBefore: Int
    ///The starting close for a new thesis, from health; nil until it answers, or if it can't.
    private var start: (date: String, price: Double?)?
    private var isNew: Bool { thesis == nil }

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private lazy var saveButton = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveTapped))
    ///The choices for both price conditions: off, or this far below.
    private static let drops: [Double] = [0.10, 0.15, 0.20, 0.25, 0.30, 0.40, 0.50]

    init(ticker: String, watchlistID: String, thesis: Thesis?) {
        self.ticker = ticker.uppercased()
        self.watchlistID = watchlistID
        self.thesis = thesis
        reason = thesis?.reason
        note = thesis?.note ?? ""
        trendBreak = thesis?.reconsiderOnTrendBreak ?? true
        belowStart = thesis?.reconsiderBelowStart
        belowHigh = thesis?.reconsiderBelowHigh
        exitGoal = thesis?.exitPlan?.goal
        exitNoDate = thesis?.exitPlan != nil && thesis?.exitPlan?.targetMonth == nil
        //Two years out until the person picks a month.
        exitTargetMonth = thesis?.exitPlan?.targetMonth ?? ExitPlan.month(of: Date().addingTimeInterval(2 * 365 * 86_400))
        exitMonthsBefore = thesis?.exitPlan?.monthsBefore ?? ExitPlan.defaultMonthsBefore
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("ThesisEditorController is built in code")
    }

    ///In its own navigation controller, as a sheet.
    func embedded() -> UINavigationController {
        let navigation = UINavigationController(rootViewController: self)
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        //Swiping down is a skip, not a lost edit: nothing is half-saved.
        navigation.isModalInPresentation = false
        return navigation
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = isNew ? "Why Watch \(Self.displaySymbol(ticker))?" : "Your Thesis"
        view.backgroundColor = UIColor(named: "colorPrimary")
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: isNew ? "Skip" : "Cancel", style: .plain,
                                                           target: self, action: #selector(skipTapped))
        navigationItem.rightBarButtonItem = saveButton
        saveButton.isEnabled = reason != nil

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .interactive
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "row")
        tableView.register(NoteCell.self, forCellReuseIdentifier: NoteCell.identifier)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        if isNew { loadStart() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        //A swipe down finishes the sheet like Skip, so the caller always hears once.
        if isBeingDismissed || navigationController?.isBeingDismissed == true { finish(nil) }
    }

    // MARK: - Starting point

    ///The last settled close, so "since you started watching" compares closes with closes.
    ///Without it the thesis still saves, dated today, and the card asks the server for the
    ///close of that day.
    private func loadStart() {
        StockAPI.shared.getStockHealth(ticker: ticker) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                if case .success(let answer) = result, let health = answer.health {
                    self.start = (health.asOf, health.close)
                } else {
                    self.start = (Self.newYorkToday(), nil)
                }
                self.tableView.reloadSections(IndexSet(integer: Section.reconsider.rawValue), with: .none)
            }
        }
    }

    private static func newYorkToday() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func displaySymbol(_ ticker: String) -> String {
        ticker.hasPrefix("^") ? String(ticker.dropFirst()) : ticker
    }

    // MARK: - Actions

    private var finished = false

    ///Calls `onFinish` once, whichever way the sheet closes.
    private func finish(_ saved: Thesis?) {
        guard !finished else { return }
        finished = true
        onFinish?(saved)
    }

    @objc private func skipTapped() {
        finish(nil)
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        guard let reason else { return }
        view.endEditing(true)
        var updated: Thesis
        if let thesis {
            updated = thesis
            updated.reason = reason
        } else {
            let start = start ?? (Self.newYorkToday(), nil)
            updated = Thesis.new(ticker: ticker, watchlistID: watchlistID, reason: reason,
                                 startDate: start.date, startPrice: start.price)
        }
        updated.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.reconsiderOnTrendBreak = trendBreak
        updated.reconsiderBelowStart = belowStart
        updated.reconsiderBelowHigh = belowHigh
        updated.exitPlan = exitPlan

        saveButton.isEnabled = false
        ThesisStore.shared.save(updated) { [weak self] error in
            guard let self else { return }
            if error != nil {
                self.saveButton.isEnabled = true
                Utilities.showAlert(on: self, title: "Can't Save", message: "Check your connection and try again.")
                return
            }
            self.thesis = updated
            self.finish(updated)
            self.dismiss(animated: true)
        }
    }

    // MARK: - Exit plan

    ///What the sheet would save, from its controls.
    private var exitPlan: ExitPlan? {
        exitGoal.map { ExitPlan(goal: $0, targetMonth: exitNoDate ? nil : exitTargetMonth, monthsBefore: exitMonthsBefore) }
    }

    private var exitRows: [ExitRow] {
        guard exitGoal != nil else { return [.goal, .why] }
        return exitNoDate ? [.goal, .why] : [.goal, .targetMonth, .monthsBefore, .why]
    }

    private func reloadExitPlan() {
        tableView.reloadSections(IndexSet(integer: Section.exitPlan.rawValue), with: .automatic)
    }

    ///None, the four goals, and "Other, no date".
    private func goalButton() -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.gray()
        configuration.cornerStyle = .capsule
        configuration.title = exitGoal.map { exitNoDate ? "\($0.title), no date" : $0.title } ?? "None"
        button.configuration = configuration
        let choose: (ExitGoal?, Bool, String) -> UIAction = { goal, noDate, title in
            UIAction(title: title, image: goal.map { UIImage(systemName: $0.symbolName) } ?? nil,
                     state: goal == self.exitGoal && noDate == self.exitNoDate ? .on : .off) { [weak self] _ in
                self?.exitGoal = goal
                self?.exitNoDate = noDate
                self?.reloadExitPlan()
            }
        }
        button.menu = UIMenu(children: [choose(nil, false, "None")]
                             + ExitGoal.allCases.map { choose($0, false, $0.title) }
                             + [choose(.other, true, "Other, no date")])
        button.showsMenuAsPrimaryAction = true
        button.sizeToFit()
        return button
    }

    private func monthsBeforeButton() -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.gray()
        configuration.cornerStyle = .capsule
        configuration.title = "\(exitMonthsBefore) months"
        button.configuration = configuration
        button.menu = UIMenu(children: ExitPlan.monthsBeforeChoices.map { months in
            UIAction(title: "\(months) months before", state: months == exitMonthsBefore ? .on : .off) { [weak self] _ in
                self?.exitMonthsBefore = months
                self?.reloadExitPlan()
            }
        })
        button.showsMenuAsPrimaryAction = true
        button.sizeToFit()
        return button
    }

    ///A month is what counts; the picker's day is ignored.
    private func monthPicker() -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .compact
        picker.minimumDate = Date()
        picker.date = ExitPlan.date(ofMonth: exitTargetMonth) ?? Date()
        picker.addAction(UIAction { [weak self] action in
            guard let picker = action.sender as? UIDatePicker else { return }
            self?.exitTargetMonth = ExitPlan.month(of: picker.date)
            self?.tableView.reloadSections(IndexSet(integer: Section.exitPlan.rawValue), with: .none)
        }, for: .valueChanged)
        return picker
    }

    ///A pull-down for one price condition: off, or one of `drops`.
    private func dropButton(current: Double?, set: @escaping (Double?) -> Void) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.gray()
        configuration.title = current.map { StockHealthFormat.unsignedPercent($0, digits: 0) } ?? "Off"
        configuration.cornerStyle = .capsule
        button.configuration = configuration
        let choose: (Double?) -> UIAction = { value in
            UIAction(title: value.map { StockHealthFormat.unsignedPercent($0, digits: 0) + " below" } ?? "Off",
                     state: value == current ? .on : .off) { [weak self] _ in
                set(value)
                self?.tableView.reloadSections(IndexSet(integer: Section.reconsider.rawValue), with: .none)
            }
        }
        button.menu = UIMenu(children: [choose(nil)] + Self.drops.map { choose($0) })
        button.showsMenuAsPrimaryAction = true
        button.sizeToFit()
        return button
    }
}

// MARK: - Table

extension ThesisEditorController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .reason: return ThesisReason.allCases.count
        case .note: return 1
        case .reconsider: return ReconsiderRow.allCases.count
        case .exitPlan: return exitRows.count
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .reason: return "Why are you watching \(Self.displaySymbol(ticker))?"
        case .note: return "In your own words (optional)"
        case .reconsider: return "What would make you look again?"
        case .exitPlan: return "Exit plan (optional)"
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if Section(rawValue: section) == .exitPlan {
            guard let plan = exitPlan else {
                return "If this money is for something, pick it and when. The app reminds you to sell gradually; it never sells anything."
            }
            switch plan.phase() {
            case .noDate: return "No date, so no reminders."
            case .before: return "\(plan.countdown). A reminder twice a year until then, then each month while you sell."
            case .selling, .past: return "\(plan.countdown)."
            }
        }
        guard Section(rawValue: section) == .reconsider else { return nil }
        var lines: [String] = []
        if let thesis {
            lines.append("Started watching on \(StockHealthFormat.day(thesis.startDate)).")
        } else if let start {
            let price = start.price.map { " at \(Self.priceText($0))" } ?? ""
            lines.append("Starts from the \(StockHealthFormat.day(start.date)) close\(price).")
        }
        lines.append("Private to your account. The app shows what happened against these, never what to do.")
        return lines.joined(separator: " ")
    }

    private static func priceText(_ value: Double) -> String {
        String(format: value < 1 ? "$%.4f" : "$%.2f", value)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .reason:
            let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
            let option = ThesisReason.allCases[indexPath.row]
            var content = cell.defaultContentConfiguration()
            content.text = option.title
            content.image = UIImage(systemName: option.symbolName)
            cell.contentConfiguration = content
            cell.accessoryView = nil
            cell.accessoryType = option == reason ? .checkmark : .none
            cell.selectionStyle = .default
            cell.accessibilityTraits = option == reason ? [.button, .selected] : .button
            return cell

        case .note:
            let cell = tableView.dequeueReusableCell(withIdentifier: NoteCell.identifier, for: indexPath) as! NoteCell
            cell.configure(text: note) { [weak self] text in self?.note = text }
            return cell

        case .reconsider:
            let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
            var content = UIListContentConfiguration.subtitleCell()
            content.secondaryTextProperties.color = .secondaryLabel
            content.secondaryTextProperties.numberOfLines = 0
            content.textProperties.numberOfLines = 0
            cell.accessoryType = .none
            cell.selectionStyle = .none
            switch ReconsiderRow(rawValue: indexPath.row)! {
            case .trendBreak:
                content.text = "Trend break"
                content.secondaryText = "Two closes more than 2% under its 200-day average"
                let toggle = UISwitch()
                toggle.isOn = trendBreak
                toggle.addAction(UIAction { [weak self] action in
                    self?.trendBreak = (action.sender as? UISwitch)?.isOn ?? false
                }, for: .valueChanged)
                cell.accessoryView = toggle
            case .belowStart:
                content.text = "Below my starting price"
                content.secondaryText = belowStart.map { "When it closes \(StockHealthFormat.unsignedPercent($0, digits: 0)) under where you started" } ?? "Off"
                cell.accessoryView = dropButton(current: belowStart) { [weak self] in self?.belowStart = $0 }
            case .belowHigh:
                content.text = "Below its high since I started"
                content.secondaryText = belowHigh.map { "When it closes \(StockHealthFormat.unsignedPercent($0, digits: 0)) under the highest close since" } ?? "Off"
                cell.accessoryView = dropButton(current: belowHigh) { [weak self] in self?.belowHigh = $0 }
            case .business:
                content.text = "Business conditions"
                content.secondaryText = "Revenue growth, margins, debt. Needs data the app doesn't have yet."
                content.textProperties.color = .secondaryLabel
                let label = UILabel()
                label.text = "Needs data"
                label.font = UIFont.preferredFont(forTextStyle: .footnote)
                label.textColor = .tertiaryLabel
                label.sizeToFit()
                cell.accessoryView = label
            }
            cell.contentConfiguration = content
            return cell

        case .exitPlan:
            let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
            var content = cell.defaultContentConfiguration()
            cell.accessoryType = .none
            cell.selectionStyle = .none
            cell.accessoryView = nil
            switch exitRows[indexPath.row] {
            case .goal:
                content.text = "Goal"
                content.image = UIImage(systemName: exitGoal?.symbolName ?? "flag")
                cell.accessoryView = goalButton()
            case .targetMonth:
                content.text = "Target month"
                cell.accessoryView = monthPicker()
            case .monthsBefore:
                content.text = "Start selling gradually"
                content.secondaryText = ExitPlan(goal: exitGoal ?? .other, targetMonth: exitTargetMonth,
                                                 monthsBefore: exitMonthsBefore).startText.map { "From \($0)" }
                cell.accessoryView = monthsBeforeButton()
            case .why:
                content.text = "Why sell gradually?"
                content.textProperties.color = .tintColor
                content.image = UIImage(systemName: "info.circle")
                cell.selectionStyle = .default
            }
            cell.contentConfiguration = content
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if Section(rawValue: indexPath.section) == .exitPlan, indexPath.row < exitRows.count, exitRows[indexPath.row] == .why {
            present(GradualExitController().embedded(), animated: true)
            return
        }
        guard Section(rawValue: indexPath.section) == .reason,
              indexPath.row < ThesisReason.allCases.count else { return }
        reason = ThesisReason.allCases[indexPath.row]
        saveButton.isEnabled = true
        tableView.reloadSections(IndexSet(integer: Section.reason.rawValue), with: .none)
    }
}

// MARK: - Note cell

///A few lines of the person's own words, with a placeholder and the length limit.
private final class NoteCell: UITableViewCell, UITextViewDelegate {

    static let identifier = "NoteCell"
    private let textView = UITextView()
    private let placeholder = UILabel()
    private var onChange: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = self
        textView.accessibilityLabel = "In your own words"
        textView.translatesAutoresizingMaskIntoConstraints = false
        placeholder.text = "AI data-centre demand, a new product, the dividend…"
        placeholder.font = textView.font
        placeholder.textColor = .tertiaryLabel
        placeholder.numberOfLines = 0
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textView)
        contentView.addSubview(placeholder)
        let margins = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: margins.topAnchor),
            textView.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 66),
            placeholder.topAnchor.constraint(equalTo: margins.topAnchor),
            placeholder.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            placeholder.trailingAnchor.constraint(equalTo: margins.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("NoteCell is built in code")
    }

    func configure(text: String, onChange: @escaping (String) -> Void) {
        textView.text = text
        placeholder.isHidden = !text.isEmpty
        self.onChange = onChange
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let current = textView.text as NSString
        return current.replacingCharacters(in: range, with: text).count <= Thesis.noteLimit
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholder.isHidden = !textView.text.isEmpty
        onChange?(textView.text)
        //Grows with the text: the table re-measures the row without a reload.
        if let table = superview as? UITableView ?? superview?.superview as? UITableView {
            UIView.performWithoutAnimation {
                table.beginUpdates()
                table.endUpdates()
            }
        }
    }
}
