# WeChat Dual Launch

[简体中文](README.md) | **English**

A macOS script to create or rebuild `WeChat2.app`, with Chinese and English prompts.

## Platform

- **macOS only.** Not for Windows, Linux, iOS or Android.
- Install the original app at `/Applications/WeChat.app`. Your account needs write access to Applications.
- **Verified version: WeChat for Mac 4.1.13.** The original and copy were observed running together, with a separate data directory for the copy. Not all features have been tested; compatibility with other versions is unverified.

## Usage

1. Download and extract the package from [Releases](https://github.com/yueshaosheng/wechat-dual-launch/releases/latest), then double-click `WeChat-Dual-Launch.command`.
2. Select `1` for Chinese (default) or `2` for English.
3. Enter `y` to start, then sign in to the second app when finished.

You do not need to delete the existing copy first or use `sudo`. If double-clicking does not work, type `zsh ` in Terminal, drag in the script, and press Return.

## How it works

The script copies the original app, changes its Bundle ID to `com.tencent.xinWeChat2`, re-signs and verifies it, installs the copy, and checks whether both processes are running. The previous copy moves to Trash only after the new copy passes verification.

The copy uses an ad-hoc signature instead of Tencent's developer signature. Some features or permissions may be affected.

## Updates and data

- Run the script again after updating the original app to rebuild the copy.
- The script does not delete chat data. The second app uses `~/Library/Containers/com.tencent.xinWeChat2` in the verified version.
- The old copy in Trash is an application backup, not a chat backup. Back up important chats before rebuilding and check that everything works before removing the old copy.

## Change the icon manually

In Applications, right-click `WeChat2.app` → **Get Info**, then drag an icon from `wechat_icons` onto the small icon at the top left of the Get Info window. The script does not replace icons automatically.
