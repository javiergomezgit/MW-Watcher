# Bullish Square

An iOS stock and crypto watchlist app. Track tickers across multiple watchlists, read
market news, and view candlestick and line charts — built in UIKit for iPhone.

Shipping as **Bullish Square** on the App Store (2.0.5). The repository, bundle id
(`com.jdev.MW-Watcher`) and Xcode target still carry the app's former name, MW Watcher.

## Features

- **Watchlists** — several named lists, each with its own tickers, logos and live prices
- **Markets** — Dow, S&P 500 and Nasdaq index charts, plus crypto quotes
- **Charts** — candlestick and line charts with OHLC detail and selectable intervals
- **News** — a live feed, per-ticker news, and bookmarked articles saved on device
- **Simulated portfolio** — a paper-trading view over the active watchlist
- **Accounts** — email and Sign in with Apple, profile editing, in-app account deletion

## Tech stack

UIKit + Storyboards (one storyboard per tab), MVC, no dependency injection. Firebase for
auth and the user document; Core Data for everything the device keeps. Charts are drawn
with DGCharts. Market, news and crypto data come from RapidAPI, yfapi.net, CoinMarketCap,
GNews, Marketaux and ElevenLabs over plain `URLSession`.

Deployment target iOS 15.6. Dependencies are split across CocoaPods and Swift Package
Manager — `Pods/` is committed, so a clone builds without running `pod install` first.

## Building

```bash
open "Bullish Square.xcworkspace"
```

Always the **workspace**, never the `.xcodeproj` — CocoaPods will not link otherwise.
Then select the `Bullish Square` scheme and run.

**A fresh clone will not compile.** Two files are deliberately untracked and must be put
in place by hand before the first build:

| File | What it is |
| --- | --- |
| `Bullish Square/Security/PrivateKeys.swift` | API keys, hosts and base URLs for every data provider |
| `Bullish Square/Security/GoogleService-Info.plist` | Firebase config, downloaded from the Firebase console |

Copy both from a machine that already has them, or regenerate them; there is no template
in the repo. There is no test target, so there is nothing to run after the build.
