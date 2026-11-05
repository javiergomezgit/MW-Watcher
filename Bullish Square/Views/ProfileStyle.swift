//
//  ProfileStyle.swift
//  Bullish Square
//

import UIKit

///The Profile screens' colours, the News card's palette: navy background, slate cards, pale
///teal text. They used the system's grouped table colours, grey cells and white text that
///matched nothing else in the app, and that turned white in light mode. (BS-260)
enum ProfileStyle {

    static let background = UIColor(named: "colorPrimary") ?? .systemGroupedBackground
    ///The card colour of the News summary card and Ask AI row.
    static let card = UIColor(red: 0.125, green: 0.161, blue: 0.239, alpha: 1)
    static let text = UIColor(named: "colorSecondary") ?? .label
    static let secondaryText = text.withAlphaComponent(0.7)
    static let placeholder = text.withAlphaComponent(0.4)
    static let accent = UIColor(named: "AccentColor") ?? .systemBlue
    static let destructive = UIColor(named: "downtrend") ?? .systemRed

    static func style(_ tableView: UITableView) {
        tableView.backgroundColor = background
        tableView.separatorColor = text.withAlphaComponent(0.12)
    }

    static func style(_ cell: UITableViewCell) {
        cell.backgroundColor = card
        cell.tintColor = accent
        let selected = UIView()
        selected.backgroundColor = text.withAlphaComponent(0.08)
        cell.selectedBackgroundView = selected
    }

    ///Section titles and notes, from willDisplayHeaderView / willDisplayFooterView.
    static func style(headerFooter view: UIView) {
        guard let view = view as? UITableViewHeaderFooterView else { return }
        var content = view.defaultContentConfiguration()
        content.text = view.textLabel?.text
        content.textProperties.color = secondaryText
        view.contentConfiguration = content
    }

    ///"Automated", with a chip symbol, wherever a Community bot appears: posts, its profile,
    ///search and follow lists. Labelled so no one mistakes a bot for a person. (BS-279)
    static func automatedBadge(font: UIFont, color: UIColor = secondaryText) -> NSMutableAttributedString {
        let symbol = UIImage(systemName: "cpu", withConfiguration: UIImage.SymbolConfiguration(font: font))?
            .withTintColor(color, renderingMode: .alwaysOriginal)
        let badge = NSMutableAttributedString(attachment: NSTextAttachment(image: symbol ?? UIImage()))
        badge.append(NSAttributedString(string: " Automated"))
        badge.addAttributes([.font: font, .foregroundColor: color], range: NSRange(location: 0, length: badge.length))
        return badge
    }

    static func style(_ content: inout UIListContentConfiguration) {
        content.textProperties.color = text
        content.secondaryTextProperties.color = secondaryText
        content.imageProperties.tintColor = accent
    }

    ///Card-coloured, no system border, the placeholder in the palette.
    static func style(_ field: UITextField) {
        field.borderStyle = .none
        field.backgroundColor = card
        field.textColor = text
        field.tintColor = accent
        field.layer.cornerRadius = 10
        field.attributedPlaceholder = NSAttributedString(string: field.placeholder ?? "",
                                                         attributes: [.foregroundColor: placeholder])
        if field.leftView == nil {
            field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
            field.leftViewMode = .always
        }
    }

    static func style(_ navigationController: UINavigationController?) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = background
        appearance.shadowColor = .clear
        //White, as the other tabs' titles are (TabTitleRow).
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = accent
    }
}
