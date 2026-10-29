// Tailwind v3 preset: in tailwind.config.js add  presets: [require('./tailwind.tokens.cjs')]
/** @type {import('tailwindcss').Config} */
module.exports = {
  theme: {
    extend: {
    colors: {
      "background": "#F7F5FC",
      "surface-container": "#ECE9F5",
      "surface-container-stronger": "#E4E0F0",
      "d-pad-center": "#E4DDF7",
      "primary": "#6041B4",
      "primary-text": "#5628CE",
      "progress-active": "#5F3DB8",
      "on-surface-strongest": "#050425",
      "on-surface": "#3C3654",
      "on-surface-variant": "#464261",
      "muted-text": "#857EA2",
      "progress-track": "#DEDBED",
      "d-pad-outline": "#DFDAF1",
      "subtle-outline": "#ECEAF8",
      "app-tile-surface": "#FBFAFE",
      "on-primary": "#F7F5FC",
      "gesture-handle": "#A7A2BE",
      "youtube-red": "#E22024",
      "netflix-red": "#EF0104",
      "hoichoi-red": "#F50304",
      "toffee-magenta": "#F326A1",
      "vlc-orange": "#F88005",
      "brand-white": "#FCF8FA"
    },
    fontFamily: {
      "sans": [
            "system-ui",
            "-apple-system",
            "sans-serif"
      ],
      "open-sans": [
            "Open Sans",
            "sans-serif"
      ]
    },
    fontSize: {
      "status-bar-time-and-battery-percentage": [
            "12px",
            {
                  "lineHeight": "17.5px",
                  "letterSpacing": "0em",
                  "fontWeight": "500"
            }
      ],
      "connected-device-title": [
            "15px",
            {
                  "lineHeight": "19.5px",
                  "letterSpacing": "-0.018em",
                  "fontWeight": "500"
            }
      ],
      "device-connection-subtitle": [
            "11px",
            {
                  "lineHeight": "16px",
                  "letterSpacing": "-0.016em",
                  "fontWeight": "500"
            }
      ],
      "current-media-title": [
            "14.5px",
            {
                  "lineHeight": "21.5px",
                  "letterSpacing": "-0.022em",
                  "fontWeight": "500"
            }
      ],
      "elapsed-playback-time": [
            "11.5px",
            {
                  "lineHeight": "16.5px",
                  "letterSpacing": "0.014em",
                  "fontWeight": "600"
            }
      ],
      "playback-separator-and-total-duration": [
            "11.5px",
            {
                  "lineHeight": "16.5px",
                  "letterSpacing": "0em",
                  "fontWeight": "500"
            }
      ],
      "selected-input-mode": [
            "11px",
            {
                  "lineHeight": "16px",
                  "letterSpacing": "0.01em",
                  "fontWeight": "500"
            }
      ],
      "unselected-input-modes": [
            "10.5px",
            {
                  "lineHeight": "15px",
                  "letterSpacing": "0.01em",
                  "fontWeight": "400"
            }
      ],
      "directional-pad-confirm-label": [
            "20.5px",
            {
                  "lineHeight": "26px",
                  "letterSpacing": "0.024em",
                  "fontWeight": "700"
            }
      ],
      "remote-action-captions": [
            "10.5px",
            {
                  "lineHeight": "14px",
                  "letterSpacing": "0.005em",
                  "fontWeight": "400"
            }
      ],
      "volume-readout": [
            "13.5px",
            {
                  "lineHeight": "20.5px",
                  "letterSpacing": "-0.041em",
                  "fontWeight": "500"
            }
      ],
      "favourite-apps-section-heading": [
            "10.5px",
            {
                  "lineHeight": "15px",
                  "letterSpacing": "0em",
                  "fontWeight": "500"
            }
      ],
      "edit-favourites-text-action": [
            "11px",
            {
                  "lineHeight": "15.5px",
                  "letterSpacing": "0em",
                  "fontWeight": "500"
            }
      ],
      "favourite-app-captions": [
            "10px",
            {
                  "lineHeight": "13.5px",
                  "letterSpacing": "0em",
                  "fontWeight": "400"
            }
      ],
      "bottom-utility-action-captions": [
            "10.5px",
            {
                  "lineHeight": "14px",
                  "letterSpacing": "0em",
                  "fontWeight": "400"
            }
      ]
    },
    borderRadius: {
      "mode-selector-outer-container": "15px",
      "selected-d-pad-segment": "15px",
      "circular-d-pad-outer-edge": "116px",
      "d-pad-ok-button": "41px",
      "back-home-and-settings-button-circles": "26.5px",
      "volume-capsule": "28.5px",
      "volume-minus-and-plus-buttons": "21px",
      "mute-button": "27px",
      "previous-and-next-transport-buttons": "27px",
      "pause-button": "30px",
      "favourite-app-tiles": "12.5px",
      "keyboard-and-power-buttons": "23px",
      "voice-button": "32.5px",
      "playback-progress-track-and-fill": "1.5px",
      "system-gesture-handle": "2px",
      "current-media-youtube-badge-approximate": "6.5px"
    },
    spacing: {
      "conversion-one-logical-dp-to-image": "1px",
      "main-content-and-left-right-screen": "233.5px",
      "device-icon-left-edge-and-device": "73px",
      "device-title-and-connection-status-line": "25px",
      "current-media-logo-right-edge-and": "19.5px",
      "media-progress-bottom-and-mode-selector": "0px",
      "mode-selector-bottom-and-directional-pad": "0px",
      "directional-pad-side-edges-and-screen": "123.5px",
      "directional-pad-bottom-and-back-home": "11.5px",
      "back-and-home-button-centers": "26px",
      "home-and-settings-button-centers": "26px",
      "back-home-settings-circles-and-caption": "3.5px",
      "back-home-settings-full-row-bottom": "15.5px",
      "volume-capsule-left-edge-and-minus": "165px",
      "volume-capsule-right-edge-and-mute": "233.5px",
      "volume-capsule-top-and-inset-buttons": "26px",
      "volume-capsule-bottom-and-pause-button": "33px",
      "transport-button-centers-horizontally": "26px",
      "pause-button-bottom-and-favourite-apps": "9.5px",
      "favourite-apps-header-block-bottom-and": "3.5px",
      "favourite-app-tile-edges-horizontally": "35.5px",
      "favourite-app-tile-bottom-and-caption": "3.5px",
      "favourite-app-caption-block-bottom-and": "14.5px",
      "divider-and-keyboard-power-circle-tops": "19.5px",
      "divider-and-voice-circle-top": "6px",
      "keyboard-voice-and-power-action-centers": "95.5px",
      "keyboard-power-circles-and-caption-line": "15px",
      "voice-circle-bottom-and-caption-line": "4px",
      "voice-caption-block-bottom-and-system": "15.5px"
    }
    },
  },
};
