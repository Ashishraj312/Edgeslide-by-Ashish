# EdgeSlide

Slide your finger along the edge of your MacBook trackpad to change **volume** or **brightness**.
A small HUD appears while you slide and disappears the moment you lift your finger.

| Edge | Gesture | Default |
|---|---|---|
| Right | slide up / down | Volume |
| Left | slide up / down | Brightness |
| Bottom | slide left / right | Off (can be enabled) |

Settings (menu-bar icon → Settings): action per edge, edge size (2–30% of the trackpad), sensitivity,
optional Option-key requirement, HUD on/off, launch at login.

**Requirements:** a Mac with a built-in trackpad, macOS 13 or newer (built and tested for Apple Silicon).
The app lives in the menu bar only (no Dock icon).

---

## Install (recommended): one command

Open **Terminal** (Cmd + Space, type `Terminal`, press Enter), paste this and press Enter:

```
curl -fsSL https://raw.githubusercontent.com/Ashishraj312/Edgeslide-by-Ashish/main/install.sh | bash
```

This downloads the latest release, puts `EdgeSlide.app` in **Applications**, and opens it.
You will see a hand icon in the menu bar. That's it.

## Install manually (download the zip)

1. Open the **Releases** page of this repo and download `EdgeSlide.zip`.
2. Double-click the zip to extract it, then drag `EdgeSlide.app` into **Applications**.
3. The app is not notarized by Apple, so macOS blocks the first launch. Fix it with either:
   - Terminal: `xattr -dr com.apple.quarantine /Applications/EdgeSlide.app`, then open the app, **or**
   - Open the app once (it will be blocked), go to **System Settings → Privacy & Security**,
     scroll down and click **Open Anyway**, then confirm.
4. Click the hand icon in the menu bar → **Settings**.

## Using it

1. Put one finger on the very edge of the trackpad (the edge area is 8% by default).
2. Slide up/down along the edge. The HUD shows the level.
3. Lift your finger and the HUD disappears.

Tips: gestures with two or more fingers are ignored, so normal scrolling is not affected.
If it triggers by accident, make the edge area smaller or turn on **Require Option key**.

## Update

Run the install command again. It replaces the old app. Your settings are kept.

## Uninstall

Quit EdgeSlide from the menu-bar icon, then:
```
rm -rf /Applications/EdgeSlide.app
```

## Build from source

```
git clone https://github.com/Ashishraj312/Edgeslide-by-Ashish.git
cd Edgeslide-by-Ashish
bash build.sh
```
If Swift is missing, run `xcode-select --install` first. The app is created in `build/EdgeSlide.app`
(and `build/EdgeSlide.zip`). An app built on your own Mac is not quarantined, so no extra step is needed.

## Troubleshooting

- **"Trackpad not found" / nothing happens:** allow EdgeSlide in
  **System Settings → Privacy & Security → Input Monitoring**, then reopen the app.
- **Blocked on first launch:** see step 3 of the manual install.
- **Stopped working after a macOS update:** EdgeSlide uses Apple's private `MultitouchSupport` and
  `DisplayServices` frameworks, which can change between macOS versions. Open an issue.

## Maintainer: publish a release

```
git tag v1.0
git push origin v1.0
```
GitHub Actions builds the app on a macOS runner and attaches `EdgeSlide.zip` to the release.
For a new version use a new tag (`v1.1`, ...).
