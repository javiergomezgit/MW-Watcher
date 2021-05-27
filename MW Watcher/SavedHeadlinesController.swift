//
//  SavedHeadlinesController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/24/21.
//

import UIKit

class SavedHeadlinesController: UIViewController {

    @IBOutlet var tableView: UITableView!
    
    let savedHeadlines = SaveHeadlines()
    var headlines: [HeadlineItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        headlines = savedHeadlines.loadHeadlines()
    }
    
    @IBAction func deleteAllButton(_ sender: UIButton) {
        savedHeadlines.deleteHeadlines(headline: "", date: "", deleteAll: true)
        headlines.removeAll()
        tableView.reloadData()
    }
    

}


extension SavedHeadlinesController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return headlines.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "headlineCell", for: indexPath) as! HeadlineViewCell
        
        cell.headlineLabel.text = headlines[indexPath.row].headline
        cell.dateLabel.text = headlines[indexPath.row].date
        
        
        return cell

    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
            return .delete
        }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete{
            let headline = headlines[indexPath.row].headline
            let date = headlines[indexPath.row].date
            savedHeadlines.deleteHeadlines(headline: headline, date: date, deleteAll: false)
            headlines.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .left)
        }
    }
}
