/**
 * @author Shakib
 * @since 29/10/26
 */
import '../remote/atv_remote.dart';
import 'remote_button.dart';

RemoteKeyCode keyCodeFor(RemoteButton button) => switch (button) {
  RemoteButton.up => RemoteKeyCode.KEYCODE_DPAD_UP,
  RemoteButton.down => RemoteKeyCode.KEYCODE_DPAD_DOWN,
  RemoteButton.left => RemoteKeyCode.KEYCODE_DPAD_LEFT,
  RemoteButton.right => RemoteKeyCode.KEYCODE_DPAD_RIGHT,
  RemoteButton.ok => RemoteKeyCode.KEYCODE_DPAD_CENTER,
  RemoteButton.back => RemoteKeyCode.KEYCODE_BACK,
  RemoteButton.home => RemoteKeyCode.KEYCODE_HOME,
  RemoteButton.settings => RemoteKeyCode.KEYCODE_SETTINGS,
  RemoteButton.volumeUp => RemoteKeyCode.KEYCODE_VOLUME_UP,
  RemoteButton.volumeDown => RemoteKeyCode.KEYCODE_VOLUME_DOWN,
  RemoteButton.mute => RemoteKeyCode.KEYCODE_VOLUME_MUTE,
  RemoteButton.playPause => RemoteKeyCode.KEYCODE_MEDIA_PLAY_PAUSE,
  RemoteButton.rewind => RemoteKeyCode.KEYCODE_MEDIA_REWIND,
  RemoteButton.fastForward => RemoteKeyCode.KEYCODE_MEDIA_FAST_FORWARD,
  RemoteButton.power => RemoteKeyCode.KEYCODE_POWER,
  RemoteButton.channelUp => RemoteKeyCode.KEYCODE_CHANNEL_UP,
  RemoteButton.channelDown => RemoteKeyCode.KEYCODE_CHANNEL_DOWN,
  RemoteButton.digit0 => RemoteKeyCode.KEYCODE_0,
  RemoteButton.digit1 => RemoteKeyCode.KEYCODE_1,
  RemoteButton.digit2 => RemoteKeyCode.KEYCODE_2,
  RemoteButton.digit3 => RemoteKeyCode.KEYCODE_3,
  RemoteButton.digit4 => RemoteKeyCode.KEYCODE_4,
  RemoteButton.digit5 => RemoteKeyCode.KEYCODE_5,
  RemoteButton.digit6 => RemoteKeyCode.KEYCODE_6,
  RemoteButton.digit7 => RemoteKeyCode.KEYCODE_7,
  RemoteButton.digit8 => RemoteKeyCode.KEYCODE_8,
  RemoteButton.digit9 => RemoteKeyCode.KEYCODE_9,
  RemoteButton.enter => RemoteKeyCode.KEYCODE_ENTER,
  RemoteButton.delete => RemoteKeyCode.KEYCODE_DEL,
};
