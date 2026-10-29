#!/bin/zsh
# Builds assets/tv_helper.jar (dex) that the app pushes to the TV and runs via app_process.
set -e
cd "$(dirname "$0")"
SDK=${ANDROID_HOME:-$HOME/Library/Android/sdk}
JAR=$SDK/platforms/android-37.0/android.jar
D8=$SDK/build-tools/36.0.0/d8
rm -rf build && mkdir -p build/classes ../assets
javac --release 8 -cp "$JAR" -d build/classes $(find src -name '*.java') 2>&1 | grep -v "^warning" || true
$D8 --min-api 21 --lib "$JAR" --output build $(find build/classes -name '*.class')
(cd build && zip -q tv_helper.jar classes.dex)
cp build/tv_helper.jar ../assets/tv_helper.jar
echo "built assets/tv_helper.jar"
