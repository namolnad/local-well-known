# local-well-known

## Table of Contents
- [Usage](#usage)
- [Overview](#overview)
- [Installation](#installation)
- [App Id Strategies](#app-id-strategies)
- [Entitlements File](#entitlements-file)
- [Other Options](#other-options)
- [License](#license)

## Usage
1. Run local-well-known from your terminal: `local-well-known --project-file MyApp.xcodeproj --scheme MyApp --entitlements-file MyApp/MyApp.entitlements`
1. Run `MyApp` from Xcode
1. Test your Universal Links, Password Autofill, etc!

## Overview
### The problem
When utilizing Apple features such as Universal Links or Password Autofill, you are required to set up a publicly available server which hosts an `.well-known/apple-app-site-association` file. Though this makes sense and prevents a myriad of takeover issues in production, it can be a painful and slow process — especially during development.

### The solution
local-well-known is a tool designed to streamline the process of getting a publicly-available `apple-app-site-association` file up and running, without needing to worry about pestering your backend team or deploying anything to production. There have been a number of articles written on the subject to make this process easier, but they all require you to manage updating config files (e.g. entitlements file) and additional tooling yourself (e.g. ngrok).

Under the hood, local-well-known spins up an extremely lightweight server to locally host a very simple `apple-app-site-association` file and [SSH is utilized](https://localhost.run) to open up a remote tunnel to make this file publicly available. If you set the corresponding `--entitlements-file` option, your entitlements file will be updated automatically.

## Installation
**Homebrew**
1. Add tap: `brew tap namolnad/formulae`
1. Install local-well-known: `brew install local-well-known`

**Mint**
1. Install mint: `brew install mint`
1. Install local-well-known: `mint install namolnad/local-well-known@main`
1. Add `~/.mint/bin` to your PATH


## App Id Strategies
There are several options available for determining the app id(s) to be hosted, ranging from automatic to fully manual/custom.

### Project/Workspace file
If you include one of the `--project-file` or `--workspace-file` options, along with the `--scheme` option, local-well-known will query Xcode to determine your app id and will host this value automatically.
### Manual
Alternatively, you can manually add the `--app-ids` option to inform local-well-known of the exact values you'd like to host.
### JSON file
If you need to utilize a more complex apple-app-site-association file, perhaps to test ignored deeplink paths, you can create this file yourself and set the `--json-file` option and your custom file will be hosted accordingly.
## Entitlements file
If the `--entitlements-file` argument is included, your entitlements file will be automatically updated to include the tunnel url for applinks and webcredentials.

## Other Options

### No Autotrust SSH
If you prefer to manage your ssh fingerprint trusting yourself, you can set the `--no-auto-trust-ssh` flag. Otherwise, `ssh-keyscan` will be used to add `localhost.run`'s SSH fingerprint to your `~/.ssh/known_hosts` file.

### Port
By default, a local server will be hosted on port 8080. If this port is already in use, you can select a different port by setting the `--port` option.

## License
local-well-known is released under the [MIT License](LICENSE)
