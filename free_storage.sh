#!/usr/bin/env bash

set -euo pipefail
shopt -s extglob

sudo rm -rf /Applications/Xcode_!(16.4).app
sudo xcrun simctl delete all
sudo rm -rf "$ANDROID_HOME"
