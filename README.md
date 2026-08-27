# Loris

Native **iOS** browser (Swift / WKWebView) for personal, on-device privacy research. Browse with the system VPN, block ads and trackers locally, and see what commercial pressure shows up in your session — without sending your traffic to a Loris backend.

> **Portfolio note:** Built as a privacy-first mobile client. Emphasis is user agency, local inspection, and reducing how much of your browsing is quietly harvested — not attacking ad networks or inflating clicks.

## Why it exists

Most “free” web experiences are funded by profiling. Loris is a small, opinionated browser that keeps the interesting work **on your phone**:

- See blocked ads/trackers and outbound ad paths in a readable log  
- Keep a local vault of detected ad targets  
- Optionally mix in **benign background page loads** (public, non-billable URLs) so interest signals are less one-dimensional  
- Never automate paid-ad clicks, conversions, or checkout flows  

Tagline in-product: *Browse quiet. Profile noisy.* — quiet for you; noisier, less precise profiles for trackers.

## Features

| Area | What you get |
| --- | --- |
| **Browser** | Minimal WKWebView client, in-app navigation, bookmarks + home icon grid |
| **Blocking** | Content-rule ad/tracker filtering (toggleable) |
| **Traffic log** | Color-coded events (blocked, taps, exits, vault, decoys, subjects…) + guide screen |
| **Ad pressure** | Best-effort subject inference from ad/overlay text; decoys prefer *counter* interests |
| **Ad vault** | Local history of detected ad destinations |
| **Privacy Lab** | Optional background decoy browsing of ordinary public pages |
| **System VPN** | Uses the iPhone VPN — no custom VPN stack inside the app |

## Design principles

1. **On-device first** — logs and vault stay local.  
2. **Transparency** — if something was blocked, vaulted, or skipped, you can see it.  
3. **No paid-click automation** — billable redirect URLs are detected, recorded, and **not** visited by the lab.  
4. **Research-safe decoys** — public category pages only; no fake purchases, forms, or install attribution.  

## Stack

- SwiftUI + WKWebView  
- `WKContentRuleList` blocker (`blockerList.json`)  
- Hidden non-persistent WKWebView for decoy loads  
- Xcode project: `SnakeBrowser.xcodeproj` (app display name **Loris**)

## Run locally

1. Open `SnakeBrowser.xcodeproj` in Xcode.  
2. Signing & Capabilities → your Apple Developer team.  
3. Run on a physical iPhone (iOS 17+).  
4. Developer Mode required for Xcode installs; TestFlight builds do not need it.

## What this is not

- Not a VPN product  
- Not an AdNauseam clone that auto-clicks ads  
- Not a tool for click fraud, budget drain, or ToS evasion as a product goal  
- Not cloud-synced surveillance of your browsing  

## Attribution

Privacy-lab concepts are **informed by** [AdNauseam](https://github.com/dhowe/AdNauseam) (see `ATTRIBUTION.md`). No AdNauseam source was copied; paid-click simulation was intentionally **not** ported.

## License

Private portfolio project unless otherwise stated by the author.
