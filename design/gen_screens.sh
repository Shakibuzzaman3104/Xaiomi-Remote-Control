#!/bin/zsh
# Renders every screen/state in the locked Remote style, 4 at a time.
K=/Users/shakib/.claude/skills/gpt-ui-assets/scripts/gptkit.py
REF=design/remote_flat/locked_v1.png
cd "/Volumes/My Files/Projects/Flutter/XiaomiRemote"

typeset -A S
S[remote_swipe]="Same Remote screen, mode switcher with 'Swipe' selected. Replace the D-pad with a large flat rounded-rectangle touch pad (same pale tint) with faint hint text in the middle: 'Swipe to move · Tap to select · Two fingers to go back'. Everything else identical."
S[remote_mouse]="Same Remote screen, mode switcher with 'Mouse' selected. Replace the D-pad with a large flat rounded-rectangle trackpad (pale tint) with a small scroll strip on its right edge, and below it two flat buttons 'Left click' and 'Right click' side by side, plus a small toggle 'Air mouse' with a phone-tilt icon. Everything else identical."
S[remote_numpad]="Same Remote screen, mode switcher with 'Numpad' selected. Replace the D-pad with a flat 3x4 number keypad (1-9, then 'CH −', 0, 'CH +') in round flat keys. Everything else identical."
S[remote_keyboard]="Same Remote screen with a bottom sheet open over the lower half: sheet title 'Typing on TV · YouTube search', a large text field showing 'bangla natok' mirrored from the TV with a cursor, buttons 'Clear' and a violet 'Send', a language chip 'EN / বাংলা', and the Android system keyboard below. Upper half (device header, now playing, D-pad) visible and dimmed."
S[remote_voice]="Same Remote screen with a voice overlay sheet from the bottom: large violet mic circle with a soft flat pulsing ring, live transcript text 'weather in Dhaka', small target chip row 'Ask Assistant' (selected) / 'Type into field', and a 'Cancel' text button. Rest of screen dimmed behind."
S[remote_disconnected]="Same Remote screen in a disconnected state: device header shows 'Living Room · Mi Box S' with status 'Reconnecting…' and a small spinner instead of 'Connected'; a flat inline banner under the header: 'TV is asleep or off Wi-Fi. Wake it with the physical remote.' with a 'Retry' text button; all remote controls shown at reduced opacity (disabled); no now-playing line."
S[remote_dark]="Exactly the same Remote screen in a dark theme: near-black background (#121016-ish), dark violet-grey surfaces for buttons and D-pad, light text, same violet accent for selected mode, OK ring, progress and Voice button. Flat, no shadows."
S[onboard_discover]="Onboarding step 1 of 3, screen title 'Find your TV'. Short subtitle 'Make sure your phone and TV are on the same Wi-Fi.' A list of discovered devices as flat rows: 'Android TV · Mi Box S · 192.168.0.103' with a TV icon and chevron (highlighted), and a second row 'Bedroom TV · Google TV · 192.168.0.120'. A small 'Searching…' indicator. Bottom: text button 'Enter IP address manually'. Step dots at top. No remote controls."
S[onboard_pair]="Onboarding step 2 of 3, title 'Pair with Mi Box S'. Subtitle 'Enter the code shown on your TV.' Six large flat code boxes with 'A 7 2 A 9' filled and the sixth focused. Below, a small illustration-free hint row with a TV icon: 'Can't see a code? Turn on the TV and keep it on the home screen.' Bottom: violet primary button 'Pair', and text button 'Read code automatically (needs full control)'. Step dots."
S[onboard_unlock]="Onboarding step 3 of 3, title 'Unlock full control'. Subtitle 'Optional. Lets you manage apps, see what's playing, take screenshots and mirror the TV.' A numbered flat checklist: 1 'On the TV open Settings › Device Preferences › About', 2 'Click Build 7 times to become a developer', 3 'Open Developer options and turn on Network debugging', 4 'Tap Connect below, then choose Always allow on the TV'. A status row 'Full control: not connected' with a grey dot. Bottom: violet primary button 'Connect', text button 'Skip for now'. Step dots."
S[apps]="Apps screen. Top app bar 'Apps' with back arrow and search icon; a search field 'Search 52 apps'. A segmented filter 'All · Favourites'. A flat grid, 4 columns, of real app tiles with names: YouTube, Netflix, Hoichoi, Toffee, VLC, Plex, Stremio, Hotstar, SonyLIV, Prime Video, Play Store, Settings, Chorki, Smarters, OTT Play, Send files. Small star on favourites. No bottom navigation."
S[app_actions]="Apps screen with a bottom sheet open for Netflix: header with Netflix icon, 'Netflix', 'com.netflix.ninja · 182 MB'. Flat action list rows with icons: 'Open on TV', 'Add to favourites', 'Force stop', 'Clear cache', 'App info on TV', and 'Uninstall' in red. Background grid dimmed."
S[now_playing]="Now Playing screen. Back arrow and title 'Now playing'. App chip 'YouTube'. Large flat placeholder artwork card (video thumbnail of a zoo with an elephant). Title 'Me at the zoo', subtitle 'jawed'. Progress scrubber 0:12 / 0:19. Transport row: replay 10, previous, big violet play/pause, next, forward 10. Volume row with − slider + and 'Volume 12'. Small row 'Sleep timer · Off'."
S[mirror]="Mirror screen. Title 'Mirror' with a 'Live' violet pill and fps '24 fps'. A 16:9 frame showing the Android TV home screen (Favourite apps row, Play Next row). A small note under it: 'Video playback appears black: the TV keeps video on a protected layer.' Below: a compact control bar Back, Home, D-pad mini, screenshot icon, fullscreen icon. Flat."
S[tools]="Tools screen. Title 'Tools'. Flat sections: 'Macros' list with 2 rows ('Movie night · Plex, volume 15' and 'Kids mode · YouTube Kids') with play buttons and a '+ New macro' row; 'Send to TV' with three tiles 'Photo or video', 'File', 'Web link'; 'Advanced' rows: 'Custom layouts', 'Screenshot', 'ADB shell', 'Device info'. No bottom navigation."
S[settings]="Settings screen. Title 'Settings'. Flat grouped list: 'Devices' (Living Room · Mi Box S · Connected; 'Add a TV'), 'Control' (Haptic feedback switch on; Volume keys control TV switch on; Swipe sensitivity slider), 'Voice' (Mic button: Ask Assistant ▾; Speech language: English + বাংলা), 'Full control' (Network debugging: Connected ✓; Companion app: Not installed › ), 'Appearance' (Theme: System ▾), 'About'."

typeset -a keys; keys=(${(k)S})
i=0
for k in $keys; do
  [[ -f design/screens/$k/mockup_v1.png ]] && continue
  python3 $K mockup "${S[$k]}" --style-ref $REF --out design/screens/$k > design/screens_logs_$k.txt 2>&1 &
  (( ++i % 4 == 0 )) && wait
done
wait
for k in $keys; do echo "== $k"; grep -E "mockup_v1.png|issues|aspect|error|Error" design/screens_logs_$k.txt | head -6; done
