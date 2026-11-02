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
    ///The chips: News tab topics, not sources. Each card shows its own source. (BS-231)
    let topics = NewsCache.topics
    var newsItems: [NewsItem] = []
    var backupNewsItems: [NewsItem] = []
    let saveHeadlines = UserSaveNews()
    var refreshControl = UIRefreshControl()
    var overlay: UIView!
    var alert: UIAlertController!
    let child = Spinner()
    
    var loadedTimes = 0
    var alreadyLaunched = false
    //Keyed by article link, not row index. Switching topic replaces newsItems wholesale,
    //so an index-keyed map rendered bookmarks against whatever article now sat at that row.
    var savedLinks: Set<String> = []
    ///Pictures loaded so far for the topic on screen, by article link. Pruned to that topic
    ///when the feed is rebuilt; other topics' pictures come back from Support.imageCache, which
    ///is bounded, rather than all being held here for good. (BS-234)
    private var articleImages: [String: UIImage] = [:]
    private var imagesInFlight: Set<String> = []
    private var imagesFailed: Set<String> = []

    ///Searches the last 20 days of Markets and Economy, whichever chip is picked. While a search
    ///is showing, the list holds its results and the chip's feed waits in backupNewsItems, so
    ///a feed arriving meanwhile does not replace them. (BS-240)
    private let searchBar = UISearchBar()
    ///The text whose results are showing or on their way; nil shows the chip's feed.
    private var searchQuery: String?
    private var pendingSearch: DispatchWorkItem?
    private let searchMessageLabel = UILabel()
    ///The list's background while a search has nothing to show: the label, kept off the edges.
    private lazy var searchMessageView: UIView = {
        let container = UIView()
        searchMessageLabel.numberOfLines = 0
        searchMessageLabel.textAlignment = .center
        searchMessageLabel.font = UIFont(name: "Avenir-Medium", size: 16) ?? .systemFont(ofSize: 16, weight: .medium)
        searchMessageLabel.textColor = UIColor(named: "colorSecondary")
        searchMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(searchMessageLabel)
        //In the upper third: centred, it sat just above the keyboard. (BS-244)
        NSLayoutConstraint.activate([
            searchMessageLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            searchMessageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
            NSLayoutConstraint(item: searchMessageLabel, attribute: .centerY, relatedBy: .equal,
                               toItem: container, attribute: .centerY, multiplier: 0.5, constant: 0)
        ])
        return container
    }()

    // MARK: - Margins (BS-244)

    ///Gap from the chips to whatever starts the list, the search field or the first story.
    ///With the chip row's own padding it matches the gap between the title and the chips.
    private static let listTopGap: CGFloat = 8
    ///Gap from the search field to the first story.
    private static let searchBottomGap: CGFloat = 16
    ///UISearchBar pads its field 8 pt at each side and 10 pt at the top. The header undoes it,
    ///so the field's edges are the stories' edges.
    private static let searchBarSidePadding: CGFloat = 8
    private static let searchBarTopPadding: CGFloat = 10
    private static let searchFieldHeight: CGFloat = 36

    ///The search bar, placed so its field lines up with the stories.
    private lazy var searchHeader: UIView = {
        let height = Self.listTopGap + Self.searchFieldHeight + Self.searchBottomGap
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: height))
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(searchBar)
        NSLayoutConstraint.activate([
            searchBar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: -Self.searchBarSidePadding),
            searchBar.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: Self.searchBarSidePadding),
            searchBar.topAnchor.constraint(equalTo: container.topAnchor, constant: Self.listTopGap - Self.searchBarTopPadding)
        ])
        return container
    }()
    ///The same gap above the first story on World, which has no search field.
    private let listTopSpacer = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: LiveNewsController.listTopGap))

    // MARK: - Market brief (BS-242)

    ///"Why markets moved", under the search field on Markets only. Nil hides the card: it is
    ///decoration, and the stories never wait for it.
    private var marketBrief: MarketBrief?
    private var briefFetchedAt: Date?
    private var briefInFlight = false
    ///The server rewrites the brief at most hourly; asking every five minutes, like the topics,
    ///picks up a new one soon after.
    private static let briefFreshness: TimeInterval = 300
    private static let briefTopic = "markets"

    private lazy var briefCard: MarketBriefCardView = {
        let card = MarketBriefCardView()
        card.isHidden = true
        card.onOpenStory = { [weak self] url in self?.openArticle(url) }
        card.onSizeChange = { [weak self] in self?.resizeListHeader() }
        return card
    }()

    // MARK: - Ask AI (BS-243)

    ///The question the status line or answer is for. Typing something else hides both.
    private var askedQuestion: String?
    ///"Asking…" or why there is no answer, for askedQuestion; nil once the answer shows.
    private var askMessage: String?
    private var hasAnswer = false

    private lazy var askButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = UIColor(red: 0.125, green: 0.161, blue: 0.239, alpha: 1)
        configuration.baseForegroundColor = UIColor(named: "AccentColor")
        configuration.image = UIImage(systemName: "sparkles")
        configuration.imagePadding = 8
        configuration.titleLineBreakMode = .byTruncatingTail
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        configuration.cornerStyle = .large
        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        button.addAction(UIAction { [weak self] _ in self?.askAI() }, for: .touchUpInside)
        return button
    }()

    private let askStatusLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont(name: "Avenir-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(named: "colorSecondary")
        return label
    }()

    private lazy var answerCard: MarketBriefCardView = {
        let card = MarketBriefCardView(bottomGap: 0)
        card.onOpenStory = { [weak self] url in self?.openArticle(url) }
        card.onSizeChange = { [weak self] in self?.resizeListHeader() }
        return card
    }()

    ///The Ask AI row, then its status or answer, with the gap to the stories below.
    private lazy var askContainer: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [askButton, askStatusLabel, answerCard])
        stack.axis = .vertical
        stack.spacing = 12
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: Self.searchBottomGap, trailing: 0)
        stack.isHidden = true
        return stack
    }()

    ///The header on the searchable chips: the search field, Ask AI while a question is typed,
    ///then the brief card when it shows. Sized to fit whenever they change, since a table
    ///header does not size itself.
    private lazy var listHeader: UIView = {
        let container = UIView()
        let stack = UIStackView(arrangedSubviews: [searchHeader, askContainer, briefCard])
        stack.axis = .vertical
        searchHeader.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            searchHeader.heightAnchor.constraint(equalToConstant: searchHeader.frame.height),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }()
    private var sizedHeaderWidth: CGFloat = -1

    ///Title, chips, search field, stories and the saved button share one margin: the view's
    ///layout margin, which is the large title's (16 pt, 20 pt on the larger phones). The chips
    ///used to touch the screen edge and the stories sat at 15 pt.
    private var appliedMargin: CGFloat = -1
    private var savedNewsTrailing: NSLayoutConstraint?

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
        setupSearchBar()
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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyMargin()
        //The card's lines wrap to the list's width, so a new width needs a new height.
        if tableView.bounds.width != sizedHeaderWidth {
            resizeListHeader()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        showImage(false)
        audioPlayer?.stop()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showImage(true)
        
        //Articles can be unsaved from the Saved News tab, so re-read rather than trusting
        //whatever this screen last wrote.
        let current = saveHeadlines.savedLinks()
        if current != savedLinks {
            savedLinks = current
            tableView.reloadData()
        }
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
        
        // Temporarily hide the "play headlines" entry point until the picker flow is finalized.
        // TODO: Re-enable this button and gesture when the headline-count picker UX is ready.
        imageViewSearchNews.isHidden = true
        imageViewSearchNews.isUserInteractionEnabled = false
        imageViewSearchNews.tintColor = .label
        
        guard let navigationBar = navigationController?.navigationBar else { return }
        navigationBar.addSubview(imageViewSavedNews)
        navigationBar.addSubview(imageViewSearchNews)
        imageViewSavedNews.translatesAutoresizingMaskIntoConstraints = false
        imageViewSearchNews.translatesAutoresizingMaskIntoConstraints = false
        
        let savedNewsTrailing = imageViewSavedNews.rightAnchor.constraint(equalTo: navigationBar.rightAnchor, constant: -Const.ImageRightMargin)
        self.savedNewsTrailing = savedNewsTrailing
        NSLayoutConstraint.activate([
            savedNewsTrailing,
            imageViewSavedNews.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -Const.ImageBottomMarginForLargeState),
            imageViewSavedNews.heightAnchor.constraint(equalToConstant: Const.ImageSizeForLargeState),
            imageViewSavedNews.widthAnchor.constraint(equalTo: imageViewSavedNews.heightAnchor),
            imageViewSearchNews.rightAnchor.constraint(equalTo: navigationBar.rightAnchor, constant: -(imageViewSavedNews.frame.width * 3)),
            imageViewSearchNews.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -Const.ImageBottomMarginForLargeState),
            imageViewSearchNews.heightAnchor.constraint(equalToConstant: Const.ImageSizeForLargeState),
            imageViewSearchNews.widthAnchor.constraint(equalTo: imageViewSavedNews.heightAnchor)
        ])
    }
    
    ///Insets the chips and the saved button to the view's margin; the stories follow it through
    ///the storyboard. Only when the margin changes, as this runs on every layout pass.
    private func applyMargin() {
        let margin = view.layoutMargins.left
        guard margin != appliedMargin else { return }
        appliedMargin = margin
        collectionLayout.sectionInset = UIEdgeInsets(top: 0, left: margin, bottom: 0, right: margin)
        collectionLayout.invalidateLayout()
        savedNewsTrailing?.constant = -margin
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
    ///The feed stays on screen while it refreshes. Refreshes the topic on screen only.
    @objc func refresh(_ sender: AnyObject) {
        //Pulling on search results searches again instead.
        if let searchQuery {
            runSearch(searchQuery)
            return
        }
        SceneDelegate.triggerNewsPrefetch(force: true)
        loadBriefIfNeeded(force: true)
    }

    ///Shows the selected topic's cached stories - the saved feed from the last launch - and
    ///lets NewsCache.didUpdate fill in the rest.
    func loadNews() {
        NotificationCenter.default.addObserver(self, selector: #selector(newsCacheDidUpdate),
                                               name: NewsCache.didUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(newsPrefetchDidFinish(_:)),
                                               name: NewsCache.prefetchDidFinish, object: nil)
        showSelectedTopic()
    }

    ///Shows the chip's topic from the cache straight away, or a spinner when it has nothing
    ///yet, and fetches it if it is older than five minutes. A fresh topic costs no request.
    private func showSelectedTopic() {
        updateListHeader()
        populateNews()
        if !NewsCache.shared.hasNews(for: NewsCache.shared.selectedTopic) {
            startStopSpinner(start: true)
        }
        SceneDelegate.triggerNewsPrefetch()
        loadBriefIfNeeded(force: false)
    }

    ///Asks for the brief when Markets is showing and the last answer is older than five
    ///minutes. A failure keeps the brief already shown, or shows no card.
    private func loadBriefIfNeeded(force: Bool) {
        guard NewsCache.shared.selectedTopic == Self.briefTopic, !briefInFlight else { return }
        if !force, let briefFetchedAt, Date().timeIntervalSince(briefFetchedAt) < Self.briefFreshness {
            return
        }
        briefInFlight = true
        NewsCallAPI.shared.loadMarketBrief { [weak self] brief in
            DispatchQueue.main.async {
                guard let self else { return }
                self.briefInFlight = false
                self.briefFetchedAt = Date()
                if let brief {
                    self.marketBrief = brief
                    self.briefCard.configure(with: brief)
                }
                self.updateListHeader()
            }
        }
    }

    @objc private func newsCacheDidUpdate() {
        populateNews()
    }

    ///Ends the refresh control and the spinner even when nothing came back (offline, quota),
    ///so neither can be left running. A topic finishing after the reader moved to another
    ///chip leaves that chip's spinner alone.
    @objc private func newsPrefetchDidFinish(_ notification: Notification) {
        if let topic = notification.object as? String, topic != NewsCache.shared.selectedTopic {
            return
        }
        refreshControl.endRefreshing()
        startStopSpinner(start: false)
    }

    private func populateNews() {
        //NewsCache posts on the main thread; this is a guard, not a hop that is expected.
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.populateNews() }
            return
        }

        let topic = NewsCache.shared.selectedTopic
        var items: [NewsItem] = []
        //Keyed by link, falling back to the headline: keying an empty link would collapse every
        //link-less article into one row.
        var seenArticles: Set<String> = []
        for var news in NewsCache.shared.get(topic) ?? [] {
            let key = news.link.isEmpty ? news.headline : news.link
            guard seenArticles.insert(key).inserted else { continue }

            //A picture already loaded for this article survives the topic being replaced by a
            //fresher copy, or the reader coming back to this chip.
            if !news.link.isEmpty, let image = articleImages[news.link] {
                news.image = image
            }
            items.append(news)
        }
        backupNewsItems = items
        //Search results stay on screen; the feed is shown again when the search ends.
        let searching = searchQuery != nil
        if !searching {
            newsItems = items
        }
        //Only the pictures of what is on screen or waiting are kept; a failed one may be tried
        //again later.
        let links = Set(items.map(\.link)).union(newsItems.map(\.link))
        articleImages = articleImages.filter { links.contains($0.key) }
        imagesFailed = imagesFailed.intersection(links)

        savedLinks = saveHeadlines.savedLinks()
        if !searching {
            tableView.reloadData()
        }
        collectionView.reloadData()
        if let index = topics.firstIndex(where: { $0.id == topic }) {
            collectionView.selectItem(at: IndexPath(item: index, section: 0), animated: false, scrollPosition: [])
        }

        if !newsItems.isEmpty {
            startStopSpinner(start: false)
            if !alreadyLaunched {
                //Once per launch: this runs each time a topic arrives.
                alreadyLaunched = true
                showFirstTimeNotification(whereView: tableView)
            }
        }
    }

    ///Loads one article's picture the first time its row is shown. Keyed by link, never by
    ///row: switching topic and fresh copies both reorder the list while it downloads.
    private func loadImageIfNeeded(for newsItem: NewsItem) {
        let link = newsItem.link
        guard !link.isEmpty,
              articleImages[link] == nil,
              !imagesInFlight.contains(link),
              !imagesFailed.contains(link),
              let url = newsItem.imageURL else { return }
        imagesInFlight.insert(link)

        Support.sharedSupport.downloadImage(from: url) { [weak self] image in
            DispatchQueue.main.async {
                guard let self else { return }
                self.imagesInFlight.remove(link)
                guard let image else {
                    //Not retried while scrolling; the placeholder stays.
                    self.imagesFailed.insert(link)
                    return
                }
                self.articleImages[link] = image
                for index in self.backupNewsItems.indices where self.backupNewsItems[index].link == link {
                    self.backupNewsItems[index].image = image
                }
                for index in self.newsItems.indices where self.newsItems[index].link == link {
                    self.newsItems[index].image = image
                    let indexPath = IndexPath(row: index, section: 0)
                    if self.tableView.indexPathsForVisibleRows?.contains(indexPath) == true {
                        self.tableView.reloadRows(at: [indexPath], with: .none)
                    }
                }
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
    ///Covers the list only, never the topic chips: a chip with nothing cached shows it while
    ///it loads, and the reader must still be able to pick another.
    func startStopSpinner(start: Bool) {
        if start {
            guard child.parent == nil else { return }
            addChild(child)
            child.view.frame = tableView.convert(tableView.bounds, to: view)
            view.addSubview(child.view)
            child.didMove(toParent: self)
        } else {
            guard child.parent != nil else { return }
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
    // TODO: Re-enable this flow after product sign-off for the headline-count picker UI.
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
        loadImageIfNeeded(for: newsItem)

        applySavedState(to: cell.saveButton, link: newsItem.link)
        
        //UIControl keeps duplicate registrations, so a reused cell fired this action once
        //per dequeue. Removing the pair first guarantees exactly one.
        cell.linkButton.removeTarget(self, action: #selector(connected(sender:)), for: .touchUpInside)
        cell.linkButton.addTarget(self, action: #selector(connected(sender:)), for: .touchUpInside)
        
        cell.saveButton.tag = indexPath.row
        cell.saveButton.removeTarget(self, action: #selector(saveTitle(sender:)), for: .touchUpInside)
        cell.saveButton.addTarget(self, action: #selector(saveTitle(sender:)), for: .touchUpInside)
        
        cell.shareButton.tag = indexPath.row
        cell.shareButton.removeTarget(self, action: #selector(shareTitle(sender:)), for: .touchUpInside)
        cell.shareButton.addTarget(self, action: #selector(shareTitle(sender:)), for: .touchUpInside)
        
        return cell
    }
    
    ///The table prepares rows before they scroll on screen, and a prepared row is shown as it
    ///was built. A picture arriving in between only redrew rows already visible, so the row
    ///came on screen with the placeholder and kept it until scrolled away and back. This runs
    ///every time a row appears, so it always gets the picture loaded so far.
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? LiveNewsViewCell,
              indexPath.row < newsItems.count,
              let image = articleImages[newsItems[indexPath.row].link] else { return }
        cell.feedImageView.image = image
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
        guard sender.tag < newsItems.count else { return }
        let newsItem = newsItems[sender.tag]
        
        //Save-or-unsave used to be decided by comparing the PNG bytes of the button's own
        //image, which made the button the source of truth. Ask the store instead.
        if savedLinks.contains(newsItem.link) {
            if saveHeadlines.deleteNews(link: newsItem.link, deleteAll: false) {
                savedLinks.remove(newsItem.link)
            } else {
                print("\(newsItem.headline) NOT UNSAVED")
            }
        } else {
            if saveHeadlines.saveNews(headline: newsItem.headline, date: newsItem.pubDate, link: newsItem.link, author: newsItem.author, imageNews: newsItem.image) {
                savedLinks.insert(newsItem.link)
                print("\(newsItem.headline) saved article")
            } else {
                print("\(newsItem.headline) NOT SAVED")
            }
        }
        
        applySavedState(to: sender, link: newsItem.link)
    }
    
    //One place decides how a bookmark looks, so a tap and a redraw cannot disagree. The
    //unsave path used to tint the button .darkGray, which reads as gone against the dark
    //background until something reloads the row.
    private func applySavedState(to button: UIButton, link: String) {
        let configuration = UIImage.SymbolConfiguration(pointSize: 22.0, weight: .regular)
        let symbol = savedLinks.contains(link) ? "bookmark.fill" : "bookmark"
        button.tintColor = UIColor(named: "colorHightlight")
        button.setImage(UIImage(systemName: symbol, withConfiguration: configuration), for: .normal)
    }
    
    // Open link in Safari View Controller
    @objc func connected(sender: UIButton) {
        guard let urlString = sender.titleLabel?.text, let url = URL(string: urlString) else { return }
        openArticle(url)
    }

    ///In the app, in Reader where the page allows; the brief card's sources open the same way.
    private func openArticle(_ url: URL) {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.delegate = self
        present(vc, animated: true)
    }
    
    // Safari delegate - placeholder for dismiss
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        // dismiss(animated: true)
    }
}

//
// MARK: - News Search
//
extension LiveNewsController: UISearchBarDelegate {

    ///In the list's header (listHeader), so it scrolls away with the stories and leaves the
    ///navigation bar, and the saved-news button pinned to it, alone.
    private func setupSearchBar() {
        searchBar.placeholder = "Search Markets & Economy news"
        searchBar.searchBarStyle = .minimal
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.returnKeyType = .search
        searchBar.tintColor = UIColor(named: "colorSecondary")
        searchBar.searchTextField.textColor = UIColor(named: "colorSecondary")
        searchBar.delegate = self
        searchBar.sizeToFit()
        tableView.keyboardDismissMode = .onDrag
    }

    ///The search field only over a chip the search covers: on World it would find none of the
    ///stories below it. The brief card only on Markets, with a brief, and not over search
    ///results, which it does not describe.
    private func updateListHeader() {
        let topic = NewsCache.shared.selectedTopic
        let searchable = topics.first { $0.id == topic }?.searchable ?? false
        briefCard.isHidden = !(topic == Self.briefTopic && marketBrief != nil && searchQuery == nil)
        updateAskViews()
        let header = searchable ? listHeader : listTopSpacer
        if tableView.tableHeaderView !== header {
            tableView.tableHeaderView = header
        }
        resizeListHeader()
    }

    ///A table header keeps the height it was given, so it is measured at the list's width and
    ///set again whenever its content or that width changes.
    private func resizeListHeader() {
        let width = tableView.bounds.width
        guard width > 0, tableView.tableHeaderView === listHeader else { return }
        sizedHeaderWidth = width
        let height = listHeader.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        guard listHeader.frame.width != width || listHeader.frame.height != height else { return }
        listHeader.frame = CGRect(x: 0, y: 0, width: width, height: height)
        tableView.tableHeaderView = listHeader
    }

    ///Searches once typing pauses, not on every letter. Fewer than two letters shows the feed.
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        pendingSearch?.cancel()
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else {
            endSearch()
            return
        }
        let work = DispatchWorkItem { [weak self] in
            self?.runSearch(text)
        }
        pendingSearch = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        pendingSearch?.cancel()
        searchBar.resignFirstResponder()
        let text = (searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { return }
        runSearch(text)
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        if (searchBar.text ?? "").isEmpty {
            searchBar.setShowsCancelButton(false, animated: true)
        }
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        clearSearch()
    }

    ///Empties the field and goes back to the chip's feed.
    private func clearSearch() {
        pendingSearch?.cancel()
        searchBar.text = ""
        searchBar.resignFirstResponder()
        searchBar.setShowsCancelButton(false, animated: true)
        endSearch()
    }

    ///Asks the server. An answer for text that is no longer the search - typed over, or
    ///cancelled - is dropped, so a slow reply cannot replace a newer one.
    private func runSearch(_ text: String) {
        searchQuery = text
        updateListHeader()
        if newsItems.isEmpty || tableView.backgroundView != nil {
            showSearchMessage("Searching…")
        }
        NewsCallAPI.shared.searchNews(query: text) { [weak self] items in
            DispatchQueue.main.async {
                guard let self else { return }
                self.refreshControl.endRefreshing()
                guard self.searchQuery == text else { return }
                guard let items else {
                    self.newsItems = []
                    self.tableView.reloadData()
                    self.showSearchMessage("Search isn't available right now.\nPull down to try again.")
                    return
                }
                self.showSearchResults(items, for: text)
            }
        }
    }

    private func showSearchResults(_ items: [NewsItem], for text: String) {
        var results: [NewsItem] = []
        var seenLinks: Set<String> = []
        for var news in items where seenLinks.insert(news.link).inserted {
            if let image = articleImages[news.link] {
                news.image = image
            }
            results.append(news)
        }
        newsItems = results
        savedLinks = saveHeadlines.savedLinks()
        tableView.reloadData()
        if results.isEmpty {
            showSearchMessage("No Markets or Economy stories from the last 20 days match “\(text)”.")
        } else {
            tableView.backgroundView = nil
            tableView.setContentOffset(.zero, animated: false)
        }
    }

    ///Back to the chip's feed, as it stands now; it kept updating during the search.
    private func endSearch() {
        guard searchQuery != nil else { return }
        searchQuery = nil
        newsItems = backupNewsItems
        tableView.backgroundView = nil
        updateListHeader()
        tableView.reloadData()
    }

    private func showSearchMessage(_ message: String) {
        //An answer on screen already says more than "no stories match".
        guard !(hasAnswer && askedQuestion == searchQuery) else { return }
        searchMessageLabel.text = message
        tableView.backgroundView = searchMessageView
    }

    // MARK: - Ask AI

    ///Questions get the Ask AI row; a word or two is a keyword search. Ends in "?", starts with
    ///a question word, or is four words or more.
    static func looksLikeQuestion(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.hasSuffix("?") { return true }
        let words = lower.split(separator: " ")
        let questionWords: Set<String> = ["why", "what", "how", "when", "who", "which", "where", "is", "are",
                                          "was", "were", "did", "does", "do", "will", "should", "can", "could"]
        if let first = words.first, questionWords.contains(String(first)), words.count >= 2 { return true }
        return words.count >= 4
    }

    ///The row while a question is typed; its status or answer once asked, for that question only.
    private func updateAskViews() {
        guard let query = searchQuery, Self.looksLikeQuestion(query) else {
            askContainer.isHidden = true
            return
        }
        askContainer.isHidden = false
        let askedThis = askedQuestion == query
        askButton.isHidden = askedThis
        askButton.configuration?.title = "Ask AI: “\(query)”"
        askStatusLabel.isHidden = !(askedThis && askMessage != nil)
        askStatusLabel.text = askMessage
        answerCard.isHidden = !(askedThis && hasAnswer)
    }

    ///Sends the question on screen. An answer arriving after the text changed is dropped.
    private func askAI() {
        guard let question = searchQuery else { return }
        searchBar.resignFirstResponder()
        askedQuestion = question
        askMessage = "Asking…"
        hasAnswer = false
        updateListHeader()

        NewsCallAPI.shared.askNews(question: question) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.askedQuestion == question else { return }
                switch result {
                case .success(let answer):
                    self.answerCard.configure(
                        title: answer.answered ? "Answer" : "No answer in the news",
                        subtitle: "Last 20 days",
                        note: "AI answer from the stories it cites · Not financial advice",
                        lines: answer.lines,
                        stories: answer.stories)
                    self.askMessage = nil
                    self.hasAnswer = true
                    self.tableView.backgroundView = nil
                case .failure(let error):
                    self.askMessage = error.message
                    self.hasAnswer = false
                }
                self.updateListHeader()
            }
        }
    }
}

//
// MARK: - Collection View Delegate/DataSource & FlowLayout
//
extension LiveNewsController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // One chip per topic
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return topics.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CollectionCell", for: indexPath) as! LiveNewsCollectionViewCell
        cell.setValues(source: topics[indexPath.row].title)
        cell.maxWidth = collectionView.bounds.width
        return cell
    }
    
    // Switches topic: cached stories at once, then a fetch if they are stale
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        //A chip is a way back to the feeds, even the one already picked.
        if searchQuery != nil || !(searchBar.text ?? "").isEmpty {
            clearSearch()
        }
        let topic = topics[indexPath.row].id
        guard topic != NewsCache.shared.selectedTopic else { return }
        NewsCache.shared.selectedTopic = topic
        refreshControl.endRefreshing()
        startStopSpinner(start: false)
        tableView.setContentOffset(.zero, animated: false)
        showSelectedTopic()
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
