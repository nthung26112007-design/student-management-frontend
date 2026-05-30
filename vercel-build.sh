#!/bin/bash
set -e

git clone https://github.com/flutter/flutter.git -b stable --depth 1 /tmp/flutter
export PATH="/tmp/flutter/bin:/tmp/flutter/bin/cache/dart-sdk/bin:$PATH"

flutter --version
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=https://student-management-backend-1-zr96.onrender.com/api
