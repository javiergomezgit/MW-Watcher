//
//  BrowserController.swift
//  MW Watcher
//
//  Created by Javier Gomez on 5/1/22.
//

import UIKit
import WebKit

class BrowserController: UIViewController, WKNavigationDelegate {

    var webView: WKWebView!
    var urlString = "https://www.jdevprojects.com/"

    override func loadView() {
        webView = WKWebView()
        webView.navigationDelegate = self
        view = webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let url = URL(string: urlString)!
        webView.load(URLRequest(url: url))
        webView.allowsBackForwardNavigationGestures = true
        
    }
}

