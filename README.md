# PS3-Rich-Presence-for-Discord
Discord Rich Presence script for PS3 consoles on HFW&HEN or CFW.

Display what game you are playing on PS3 via your PC!

## Display Example
<table>
	<tr>
		<th></th>
		<th>AppName (original style)</th>
		<th>GameName (new style)</th>
	</tr>
	<tr>
		<td>XMB</td>
		<td> <img src="https://github.com/zorua98741/PS3-Rich-Presence-for-Discord/blob/main/img/xmb.png?raw=true"> </td>
		<td> <img src="https://github.com/zorua98741/PS3-Rich-Presence-for-Discord/blob/main/img/xmb2025.png?raw=true"></td>
	</tr>
	<tr>
		<td>PS3</td>
		<td> <img src="https://github.com/zorua98741/PS3-Rich-Presence-for-Discord/blob/main/img/ps3.png?raw=true"> </td>
		<td> <img src="https://github.com/zorua98741/PS3-Rich-Presence-for-Discord/blob/main/img/ps32025.png?raw=true"></td>
	</tr>
	<tr>
		<td>PS1/2</td>
		<td> <img src="https://github.com/zorua98741/PS3-Rich-Presence-for-Discord/blob/main/img/retro.png?raw=true"> </td>
		<td> <img src="https://github.com/zorua98741/PS3-Rich-Presence-for-Discord/blob/main/img/retro2025.png?raw=true"></td>
	</tr>
</table>


## Usage

### Requirements
* PS3 with either HFW&HEN, or CFW installed
* PS3 with [webmanMOD](https://github.com/aldostools/webMAN-MOD/releases) installed 
* PS3 and PC on the same network/internet connection
* Discord installed and open on the PC running the script
* Python 3.9 or newer

### Cross-platform CLI

The original Python worker remains available on Windows, Linux, and macOS. Run it from the project directory with [uv](https://docs.astral.sh/uv/):

```bash
uv run --script PS3RPD.py
```

The `start.py` launcher provides the same command for Windows, Linux, and macOS terminals. The native SwiftUI app and drag-and-drop DMG are macOS-specific additions; they do not remove the original cross-platform worker.

### macOS 15 Sequoia and newer

Install Python 3.9 or newer and the Discord desktop app. Homebrew is the simplest option:

```bash
brew install python
git clone https://github.com/your-user/PS3-Rich-Presence-for-Discord-macOS ~/ps3-rich-presence-macos
cd ~/ps3-rich-presence-macos
open "dist/PS3 Rich Presence.app"
```

This opens the PS3 Rich Presence desktop app. The first run creates `.venv` and installs the dependencies automatically. Enter the PS3 IP and Discord application ID in the window, click **Test PS3**, then click **Start Presence**. Keep Discord open while the app is running.

Rich Presence appears on your personal Discord account through the open Discord desktop app. No bot account, bot invite, or bot token is used. The required app ID is copied from **Discord Developer Portal > Applications > your application > General Information > Application ID**. A random Discord user ID or bot token will produce `Client ID is Invalid`.

To build the distributable installer from source:

```bash
./build_dmg.sh
open "dist/PS3-Rich-Presence-macOS.dmg"
```

The generated app uses the macOS 26 Liquid Glass API when built with the macOS 26 SDK. On macOS 15 it uses the matching translucent material fallback. The packaged files are `dist/PS3 Rich Presence.app` and `dist/PS3-Rich-Presence-macOS.dmg`.

### Project structure

* `Sources/PS3RichPresence/main.swift` - native SwiftUI app and Discord/PS3 controls
* `Assets/AppIcon.svg` - source artwork for the macOS app icon
* `Info.plist` - app metadata and icon declaration
* `PS3RPD.py` - PS3 webMAN and Discord Rich Presence worker
* `bootstrap.py` - creates the Python environment, then starts the worker
* `build_dmg.sh` - builds the `.app`, generates `AppIcon.icns`, and creates the DMG




### GameTDB
This script can utilise images provided by [GameTDB](https://www.gametdb.com/), if you are able, consider supporting the service.

### External config file
PS3RPD makes use of an external config file to persistently store a few variables, on creation, the default values will be:
* Your PS3's IP address 	(where the script will find your PS3 on the network)
* My Discord developer application's ID 		(where the script will send presence data to)
* A refresh time of 35 seconds 					(how often to get new data (minimum value of 15 seconds)
* To show the PS3's temperature
* To use a shared cover for PS2&PSX games
* To display the time elapsed

### Using your own images
If you'd like to control what images are used for each game, you must create a Discord Developer Application over at the [Discord Developer Portal](https://discord.com/developers/applications).

Once created, copy the application ID from the Developer Portal and paste it into the external `ps3rpdconfig.json`, replacing the value of `client_id`.

You are now able to upload your own assets in the Developer Portal under `Rich Presence > Art Assets`. Note that the name of the asset uploaded must be the lowercase title ID provided in the script's output. (e.g. `abcd12345`)

## [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/N4N87V7K5) [![pypresence](https://img.shields.io/badge/using-pypresence-00bb88.svg?style=for-the-badge&logo=discord&logoWidth=20)](https://github.com/qwertyquerty/pypresence)
