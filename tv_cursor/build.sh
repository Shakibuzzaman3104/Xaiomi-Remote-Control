#!/bin/zsh
set -e
cd "$(dirname "$0")"
SDK=${ANDROID_HOME:-$HOME/Library/Android/sdk}
JAR=$SDK/platforms/android-37.0/android.jar
TOOLS=$SDK/build-tools/36.0.0
PASS=${XR_CURSOR_KEY_PASS:?Set XR_CURSOR_KEY_PASS to the signing keystore password}
rm -rf build
mkdir -p build/compiled build/classes .signing ../assets
if [[ ! -f .signing/release.keystore ]]; then
  keytool -genkeypair -keystore .signing/release.keystore -storepass "$PASS" -keypass "$PASS" -alias xrcursor -keyalg RSA -keysize 2048 -validity 10000 -dname 'CN=Xiaomi Remote Cursor'
fi
"$TOOLS/aapt2" compile --dir res -o build/compiled
"$TOOLS/aapt2" link -o build/unsigned.apk --manifest AndroidManifest.xml -I "$JAR" --min-sdk-version 24 --target-sdk-version 28 --version-code 1 --version-name 1 --java build $(find build/compiled -name '*.flat')
javac --release 8 -cp "$JAR" -d build/classes $(find src -name '*.java')
"$TOOLS/d8" --min-api 24 --lib "$JAR" --output build $(find build/classes -name '*.class')
(cd build && zip -q unsigned.apk classes.dex)
"$TOOLS/zipalign" -p 4 build/unsigned.apk build/aligned.apk
"$TOOLS/apksigner" sign --v4-signing-enabled false --ks .signing/release.keystore --ks-key-alias xrcursor --ks-pass env:XR_CURSOR_KEY_PASS --key-pass env:XR_CURSOR_KEY_PASS --out ../assets/tv_cursor.apk build/aligned.apk
echo 'built assets/tv_cursor.apk'
