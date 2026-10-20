#!/usr/bin/env bash
set -euo pipefail
sudo apt-get update
sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa
if [ ! -d /home/node/flutter ]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /home/node/flutter
fi
export PATH="/home/node/flutter/bin:$PATH"
flutter config --enable-web
flutter precache --web
flutter pub get
npm ci --prefix server
