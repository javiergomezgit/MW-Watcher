//
//  ViewController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/1/21.
//

import UIKit
import CoreData
import SafariServices
import AMPopTip
import AVFoundation

class LiveNewsController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var stackViewPlayer: UIStackView!
    @IBOutlet weak var backwardButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var loopButton: UIButton!
    
    @IBOutlet weak var collectionLayout: UICollectionViewFlowLayout! {
        didSet {
            collectionLayout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        }
    }
    
    // MARK: - Properties
    var sources = ["ALL"]
    var newsItems: [NewsItem] = []
    var backupNewsItems: [NewsItem] = []
    let saveHeadlines = UserSaveNews()
    var refreshControl = UIRefreshControl()
    var overlay: UIView!
    var alert: UIAlertController!
    let child = Spinner()
    
    var loadedTimes = 0
    var alreadyLaunched = false
    var savedRows: [Int: Bool] = [:]
    
    private let imageViewSavedNews = UIImageView(image: UIImage(named: "tray.2.fill"))
    private let imageViewSearchNews = UIImageView(image: UIImage(systemName: "play.circle"))
    
    // MARK: - Audio Properties
    private var audioPlayer: AVAudioPlayer?
    private var audioData: Data?
    private var isLoopEnabled = false
    private var headlineUpdateTimer: Timer?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPlayerControls()
        
        tableView.delegate = self
        tableView.dataSource = self
        collectionView.delegate = self
        collectionView.dataSource = self
        
        // Setup pull-to-refresh
        refreshControl.attributedTitle = NSAttributedString(string: "Loading")
        refreshControl.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)
        tableView.addSubview(refreshControl)
        
        // Onboarding check
        let isFirstLaunch = UserDefaults.standard.bool(forKey: "firstLaunchingLiveNews")
        UserDefaults.standard.set(true, forKey: "firstLaunchingLiveNews")
        alreadyLaunched = isFirstLaunch
        
        // Initial load
        loadNews()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        showImage(false)
        audioPlayer?.stop()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showImage(true)
    }
}

//
// MARK: - UI Setup
//
extension LiveNewsController {
    
    // Navigation bar setup with action buttons
    private func setupUI() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageSavedNewsTapped(tapGestureRecognizer:)))
        imageViewSavedNews.isUserInteractionEnabled = true
        imageViewSavedNews.tintColor = .label
        imageViewSavedNews.addGestureRecognizer(tapGestureRecognizer)
        
        let tapGestureRecognizerSearch = UITapGestureRecognizer(target: self, action: #selector(imagePlayAudioNewsTapped(tapGestureRecognizer:)))
        imageViewSearchNews.isUserInteractionEnabled = true
        imageViewSearchNews.tintColor = .label
        imageViewSearchNews.addGestureRecognizer(tapGestureRecognizerSearch)
        
        guard let navigationBar = navigationController?.navigationBar else { return }
        navigationBar.addSubview(imageViewSavedNews)
        navigationBar.addSubview(imageViewSearchNews)
        imageViewSavedNews.translatesAutoresizingMaskIntoConstraints = false
        imageViewSearchNews.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageViewSavedNews.rightAnchor.constraint(equalTo: navigationBar.rightAnchor, constant: -Const.ImageRightMargin),
            imageViewSavedNews.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -Const.ImageBottomMarginForLargeState),
            imageViewSavedNews.heightAnchor.constraint(equalToConstant: Const.ImageSizeForLargeState),
            imageViewSavedNews.widthAnchor.constraint(equalTo: imageViewSavedNews.heightAnchor),
            imageViewSearchNews.rightAnchor.constraint(equalTo: navigationBar.rightAnchor, constant: -(imageViewSavedNews.frame.width * 3)),
            imageViewSearchNews.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -Const.ImageBottomMarginForLargeState),
            imageViewSearchNews.heightAnchor.constraint(equalToConstant: Const.ImageSizeForLargeState),
            imageViewSearchNews.widthAnchor.constraint(equalTo: imageViewSavedNews.heightAnchor)
        ])
    }
    
    // Animate showing/hiding top bar buttons
    private func showImage(_ show: Bool) {
        UIView.animate(withDuration: 0.2) {
            self.imageViewSavedNews.alpha = show ? 1.0 : 0.0
            self.imageViewSearchNews.alpha = show ? 1.0 : 0.0
        }
    }
    
    // Show onboarding tip for new users
    func showFirstTimeNotification(whereView: UIView) {
        let popTip = PopTip()
        popTip.delayIn = TimeInterval(1)
        popTip.actionAnimation = .bounce(2)
        
        let positionPoptip = CGRect(x: whereView.frame.maxX - 50, y: whereView.frame.minY - 20, width: 100, height: 100)
        popTip.show(text: "You can save your favorite news", direction: .left, maxWidth: 150, in: view, from: positionPoptip)
        
        popTip.bubbleColor = UIColor(named: "onboardingNotification")!
        popTip.shouldDismissOnTap = true
    }
}

//
// MARK: - News Loading
//
extension LiveNewsController {
    
    // Handle pull-to-refresh
    @objc func refresh(_ sender: AnyObject) {
        loadNews()
    }
    
    // Load news from multiple sources
    func loadNews() {
        refreshControl.beginRefreshing()
        startStopSpinner(start: true)
        
        let selectedSources = ["business", "world", "general"]
        var error = false
        var tempSources: Set<String> = []
        var count = 0
        
        for source in selectedSources {
            NewsCallAPI.shared.loadAllNews(keySource: source) { allNews in
                if allNews == nil {
                    print("Error getting from one of the sources")
                    error = true
                } else {
                    if count == 0 {
                        self.sources.removeAll()
                        self.newsItems.removeAll()
                        self.backupNewsItems.removeAll()
                        self.sources.append("ALL")
                    }
                    for news in allNews! {
                        let inserted = tempSources.insert(news.author)
                        if inserted.inserted {
                            self.sources.append(news.author)
                        }
                        self.newsItems.append(news)
                        self.backupNewsItems.append(news)
                    }
                    
                    if selectedSources.count - 1 == count {
                        DispatchQueue.main.async {
                            self.sources.sort()
                            self.tableView.reloadData()
                            self.collectionView.reloadData()
                            self.refreshControl.endRefreshing()
                            self.startStopSpinner(start: false)
                            if !self.alreadyLaunched {
                                self.showFirstTimeNotification(whereView: self.tableView)
                            }
                            print("News items loaded: \(self.newsItems.count)")
                        }
                    }
                }
                count += 1
            }
        }
        
        if error {
            DispatchQueue.main.async {
                ShowAlerts.showSimpleAlert(title: "Error", message: "Connection Error, try later!", titleButton: "OK", over: self)
            }
        }
    }
}

//
// MARK: - Audio Management
//
extension LiveNewsController {
    
    // Prepare and request combined audio for selected headlines using API
    func loadAudioForSelectedHeadlines(numberOfHeadlines: Int) {
        startStopSpinner(start: true)
        audioData = nil
        audioPlayer?.stop()
        stopHeadlineUpdateTimer()
        audioPlayer = nil
        
        let selectedHeadlines = Array(newsItems.prefix(numberOfHeadlines))
        let combinedHeadlines = selectedHeadlines.map { news in
            news.headline
                .replacingOccurrences(of: ".", with: ". ")
                .replacingOccurrences(of: "U.S.", with: "United States")
            + ". "
        }.joined()
        
        if combinedHeadlines.count > 10000 {
            DispatchQueue.main.async {
                self.startStopSpinner(start: false)
                Utilities.showErrorAlert(on: self, message: "Selected headlines exceed 10,000 characters. Please select fewer headlines.")
            }
            return
        }
        
        guard let url = URL(string: "\(KeysNewsCallAPI.elevenLabsBaseURL)/\(KeysNewsCallAPI.voiceID)") else {
            DispatchQueue.main.async {
                self.startStopSpinner(start: false)
                Utilities.showErrorAlert(on: self, message: "Invalid API URL.")
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(KeysNewsCallAPI.elevenLabsAPIKey, forHTTPHeaderField: "xi-api-key")
        
        let parameters: [String: Any] = [
            "text": combinedHeadlines,
            "voice_settings": [
                "stability": 0.6,
                "similarity_boost": 0.8,
                "speed": 1.0
            ],
            "model_id": "eleven_monolingual_v1",
            "output_format": "mp3"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            print("Error encoding JSON: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.startStopSpinner(start: false)
                Utilities.showErrorAlert(on: self, message: "Failed to prepare audio.")
            }
            return
        }
        
        print("Fetching audio for \(numberOfHeadlines) headlines, total characters: \(combinedHeadlines.count)")
        print("Request URL: \(url.absoluteString)")
        print("Request Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.startStopSpinner(start: false)
            }
            
            if let error = error {
                print("API request failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    Utilities.showErrorAlert(on: self, message: "Unable to generate audio: \(error.localizedDescription)")
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response")
                DispatchQueue.main.async {
                    Utilities.showErrorAlert(on: self, message: "Invalid server response.")
                }
                return
            }
            
            if httpResponse.statusCode == 401 {
                print("Unauthorized: Invalid or missing API key. Key used: \(KeysNewsCallAPI.elevenLabsAPIKey.prefix(4))... (length: \(KeysNewsCallAPI.elevenLabsAPIKey.count))")
                if let data = data, let errorBody = try? JSONSerialization.jsonObject(with: data) {
                    print("Error Response: \(errorBody)")
                }
                DispatchQueue.main.async {
                    Utilities.showErrorAlert(on: self, message: "Invalid ElevenLabs API key. Please verify your API key in the ElevenLabs dashboard or generate a new one.")
                }
                return
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                print("HTTP Error: Status \(httpResponse.statusCode)")
                if let data = data, let errorBody = try? JSONSerialization.jsonObject(with: data) {
                    print("Error Response: \(errorBody)")
                }
                DispatchQueue.main.async {
                    Utilities.showErrorAlert(on: self, message: "Failed to generate audio. HTTP Status: \(httpResponse.statusCode)")
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    Utilities.showErrorAlert(on: self, message: "No audio data received.")
                }
                return
            }
            
            DispatchQueue.main.async {
                self.audioData = data
                do {
                    self.audioPlayer = try AVAudioPlayer(data: data)
                    self.audioPlayer?.delegate = self
                    self.audioPlayer?.numberOfHeadlines = numberOfHeadlines
                    self.audioPlayer?.prepareToPlay()
                    self.audioPlayer?.play()
                    self.playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
                    self.stackViewPlayer.isHidden = false
                    print("Playing combined audio for \(numberOfHeadlines) headlines")
                } catch {
                    print("Error playing audio: \(error.localizedDescription)")
                    Utilities.showErrorAlert(on: self, message: "Failed to play audio.")
                }
            }
        }
        task.resume()
    }
    
    // Setup player controls button images and actions
    private func setupPlayerControls() {
        backwardButton.setImage(UIImage(systemName: "backward.fill"), for: .normal)
        playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        loopButton.setImage(UIImage(systemName: "repeat"), for: .normal)
        
        backwardButton.addTarget(self, action: #selector(restartAudio), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(togglePlayPause), for: .touchUpInside)
        loopButton.addTarget(self, action: #selector(toggleLoop), for: .touchUpInside)
        
        backwardButton.accessibilityLabel = "Restart audio"
        playButton.accessibilityLabel = "Play or pause audio"
        loopButton.accessibilityLabel = "Toggle loop mode"
        
        stackViewPlayer.isHidden = true
    }
    
    // Restart audio from beginning and play if paused
    @objc func restartAudio() {
        audioPlayer?.currentTime = 0
        if audioPlayer?.isPlaying == false {
            audioPlayer?.play()
            playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
    }
    
    // Toggle play/pause audio state
    @objc func togglePlayPause() {
        guard audioPlayer != nil else {
            Utilities.showErrorAlert(on: self, message: "No audio available. Please select headlines to play.")
            return
        }
        
        if audioPlayer?.isPlaying == true {
            audioPlayer?.pause()
            playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            stopHeadlineUpdateTimer()
        } else {
            audioPlayer?.play()
            playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
    }
    
    // Toggle looping playback state
    @objc func toggleLoop() {
        isLoopEnabled.toggle()
        loopButton.tintColor = isLoopEnabled ? .red : .label
        loopButton.setImage(UIImage(systemName: "repeat"), for: .normal)
    }
    
    // Stop audio headline update timer
    private func stopHeadlineUpdateTimer() {
        headlineUpdateTimer?.invalidate()
        headlineUpdateTimer = nil
    }
}

//
// MARK: - Navigation Button Handling
//
extension LiveNewsController {
    
    private struct Const {
        static let ImageSizeForLargeState: CGFloat = 36
        static let ImageRightMargin: CGFloat = 18
        static let ImageBottomMarginForLargeState: CGFloat = 14
        static let ImageBottomMarginForSmallState: CGFloat = 5
        static let ImageSizeForSmallState: CGFloat = 20
        static let NavBarHeightSmallState: CGFloat = 44
        static let NavBarHeightLargeState: CGFloat = 96.5
    }
    
    // Show or hide loading spinner overlay
    func startStopSpinner(start: Bool) {
        if start {
            addChild(child)
            child.view.frame = view.frame
            view.addSubview(child.view)
            child.didMove(toParent: self)
        } else {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
    }
    
    // Open saved news screen
    @objc func imageSavedNewsTapped(tapGestureRecognizer: UITapGestureRecognizer) {
        let storyboard = UIStoryboard(name: "Singles", bundle: Bundle.main)
        let destination = storyboard.instantiateViewController(identifier: "savednews") as? SavedNewsController
        destination!.modalTransitionStyle = .coverVertical
        destination!.modalPresentationStyle = .fullScreen
        self.show(destination!, sender: self)
    }
    
    // Show alert to select number of news headlines to play audio
    @objc func imagePlayAudioNewsTapped(tapGestureRecognizer: UITapGestureRecognizer) {
        let numberOfNews = newsItems.count
        if numberOfNews == 0 {
            Utilities.showErrorAlert(on: self, message: "No news items available.")
            return
        }
        
        let alert = UIAlertController(title: "Select Number of News", message: "Choose how many news headlines to listen to (1 - \(numberOfNews)).", preferredStyle: .alert)
        
        let picker = UIPickerView()
        picker.dataSource = self
        picker.delegate = self
        picker.tag = 100
        
        alert.view.addSubview(picker)
        picker.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 40),
            picker.leftAnchor.constraint(equalTo: alert.view.leftAnchor, constant: 20),
            picker.rightAnchor.constraint(equalTo: alert.view.rightAnchor, constant: -20),
            picker.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -60)
        ])
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            let selectedRow = picker.selectedRow(inComponent: 0)
            let numberOfHeadlines = selectedRow + 1
            self.loadAudioForSelectedHeadlines(numberOfHeadlines: numberOfHeadlines)
        })
        
        present(alert, animated: true)
    }
}

//
// MARK: - Table View Delegate/DataSource
//
extension LiveNewsController: UITableViewDelegate, UITableViewDataSource, SFSafariViewControllerDelegate {
    
    // Return count of news items for table
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return newsItems.count
    }
    
    // Configure and return cell for news item row
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LiveNewsViewCell", for: indexPath) as! LiveNewsViewCell
        let newsItem = newsItems[indexPath.row]
        
        cell.setNewsValues(headline: newsItem.headline, link: newsItem.link, pubdate: newsItem.pubDate, author: newsItem.author, imageFeed: newsItem.image)
        
        let configuration = UIImage.SymbolConfiguration(pointSize: 22.0, weight: .regular)
        if savedRows[indexPath.row] == true {
            cell.saveButton.tintColor = UIColor(named: "colorHightlight")
            cell.saveButton.setImage(UIImage(systemName: "bookmark.fill", withConfiguration: configuration), for: .normal)
        } else {
            cell.saveButton.tintColor = UIColor(named: "colorHightlight")
            cell.saveButton.setImage(UIImage(systemName: "bookmark", withConfiguration: configuration), for: .normal)
        }
        
        cell.linkButton.addTarget(self, action: #selector(connected(sender:)), for: .touchUpInside)
        
        cell.saveButton.tag = indexPath.row
        cell.saveButton.addTarget(self, action: #selector(saveTitle(sender:)), for: .touchUpInside)
        
        cell.shareButton.tag = indexPath.row
        cell.shareButton.addTarget(self, action: #selector(shareTitle(sender:)), for: .touchUpInside)
        
        return cell
    }
    
    // Share news headline and details
    @objc func shareTitle(sender: UIButton) {
        sender.animateButton(sender: sender, duration: 0.1)
        
        let newsItem = self.newsItems[sender.tag]
        let headline = newsItem.headline
        let date = newsItem.pubDate
        let author = newsItem.author
        let link = newsItem.link
        let image = newsItem.image
        
        let formattedText = """
        📰 \(headline)
        📅 \(date)
        👤 Source: \(author)
        🔗 Read more: \(link)
        Shared via Bullish Square 📱
        """
        
        var activityItems: [Any] = [formattedText]
        if image.size.width > 1 && image.size.height > 1 {
            activityItems.append(image)
        } else {
            activityItems.append(UIImage(named: "mw-logo")!)
        }
        
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        present(activityVC, animated: true)
    }
    
    // Save or remove news headline from saved list
    @objc func saveTitle(sender: UIButton) {
        sender.animateButton(sender: sender, duration: 0.1)
        let headline = self.newsItems[sender.tag].headline
        let dateOfNew = self.newsItems[sender.tag].pubDate
        let link = self.newsItems[sender.tag].link
        let source = self.newsItems[sender.tag].author
        let imageNews = self.newsItems[sender.tag].image
        
        let configurationButton = sender.currentImage?.configuration
        var boldSearch = UIImage()
        
        let currentImageData = sender.currentImage
        let imageData = UIImage(systemName: "bookmark", withConfiguration: configurationButton)
        
        if currentImageData?.pngData() == imageData?.pngData() {
            if saveHeadlines.saveNews(headline: headline, date: dateOfNew, link: link, author: source, imageNews: imageNews) {
                sender.tintColor = .red
                boldSearch = UIImage(systemName: "bookmark.fill", withConfiguration: configurationButton)!
                print("\(headline) saved article")
                self.savedRows[sender.tag] = true
            } else {
                print("\(headline) NOT SAVED")
            }
        } else {
            if saveHeadlines.deleteNews(headline: headline, date: dateOfNew, deleteAll: false)! {
                sender.tintColor = .darkGray
                boldSearch = UIImage(systemName: "bookmark", withConfiguration: configurationButton)!
                self.savedRows[sender.tag] = false
            } else {
                print("\(headline) NOT UNSAVED")
            }
        }
        sender.setImage(boldSearch, for: .normal)
    }
    
    // Open link in Safari View Controller
    @objc func connected(sender: UIButton) {
        guard let urlString = sender.titleLabel?.text else { return }
        
        if let url = URL(string: urlString) {
            let config = SFSafariViewController.Configuration()
            config.entersReaderIfAvailable = true
            let vc = SFSafariViewController(url: url, configuration: config)
            vc.delegate = self
            present(vc, animated: true)
        }
    }
    
    // Safari delegate - placeholder for dismiss
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        // dismiss(animated: true)
    }
}

//
// MARK: - Collection View Delegate/DataSource & FlowLayout
//
extension LiveNewsController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // Number of source items for collection
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sources.count
    }
    
    // Setup each source cell
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CollectionCell", for: indexPath) as! LiveNewsCollectionViewCell
        //cell.backgroundColor = UIColor(named: "colorSecondary")

        let text = sources[indexPath.row]
        cell.setValues(source: text)
        cell.maxWidth = collectionView.bounds.width
        return cell
    }
    
    // Filter news items by selected source
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        //let cell = collectionView.cellForItem(at: indexPath)
        //cell?.backgroundColor = UIColor(named: "colorAccent")
        
        let selectedSource = sources[indexPath.row]
        
        if selectedSource == "ALL" {
            newsItems = backupNewsItems
        } else {
            var tempNew: [NewsItem] = []
            for newsItem in backupNewsItems {
                if newsItem.author == selectedSource {
                    tempNew.append(newsItem)
                }
            }
            newsItems = tempNew
        }
        tableView.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
//        let cell = collectionView.cellForItem(at: indexPath)
//        cell?.backgroundColor = UIColor(named: "colorSecondary")
    }
    
    // Cell size for collection view
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 25, height: 35)
    }
    
    // Minimum horizontal spacing between cells
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 15.0
    }
    
    // Minimum vertical line spacing for cells
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10.0
    }
}

//
// MARK: - Picker View Delegate/DataSource
//
extension LiveNewsController: UIPickerViewDelegate, UIPickerViewDataSource {
    
    // One component in picker
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // Number of rows equals number of news items
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return newsItems.count
    }
    
    // Row title is simply the number
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return "\(row + 1)"
    }
}

//
// MARK: - AVAudioPlayer Delegate
//
extension LiveNewsController: AVAudioPlayerDelegate {
    
    // Loop or stop audio when finished playing
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag && isLoopEnabled {
            player.currentTime = 0
            player.play()
            playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        } else {
            playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            stackViewPlayer.isHidden = true
            stopHeadlineUpdateTimer()
        }
    }
    
    // Handle audio decode errors
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio decode error: \(error?.localizedDescription ?? "Unknown")")
        DispatchQueue.main.async {
            Utilities.showErrorAlert(on: self, message: "Failed to decode audio.")
            self.playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            self.stackViewPlayer.isHidden = true
            self.stopHeadlineUpdateTimer()
        }
    }
}
