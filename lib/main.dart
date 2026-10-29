/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import 'ui/theme/app_theme.dart';
import 'ui/theme/app_colors.dart';
import 'ui/remote/remote_models.dart';
import 'ui/remote/remote_screen.dart';

void main() => runApp(const XiaomiRemoteApp());

class XiaomiRemoteApp extends StatelessWidget {
  const XiaomiRemoteApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Xiaomi Remote',
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.system,
    home: Builder(
      builder: (context) {
        final c = context.colors;
        final names = [
          'YouTube',
          'Netflix',
          'Hoichoi',
          'Toffee',
          'VLC',
          'Plex',
        ];
        final colors = [
          c.danger,
          c.primary,
          c.connected,
          c.primaryText,
          c.muted,
          c.onSurface,
        ];
        return RemoteScreen(
          state: RemoteViewState(
            deviceName: 'Living Room · Mi Box S',
            connected: true,
            reconnecting: false,
            nowPlaying: const NowPlaying(
              title: 'Me at the zoo',
              position: Duration(seconds: 12),
              duration: Duration(seconds: 19),
              playing: true,
            ),
            volumeLevel: 12,
            muted: false,
            favourites: List.generate(
              names.length,
              (i) => FavouriteApp(
                id: names[i],
                label: names[i],
                icon: CircleAvatar(
                  radius: 16,
                  backgroundColor: colors[i],
                  child: Text(
                    names[i][0],
                    style: TextStyle(
                      color: c.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          onButton: (v) => debugPrint('Button: $v'),
          onSwitchDevice: () => debugPrint('Switch device'),
          onOpenNowPlaying: () => debugPrint('Now playing'),
          onOpenApp: (v) => debugPrint('App: ${v.id}'),
          onEditFavourites: () => debugPrint('Edit favourites'),
          onKeyboard: () => debugPrint('Keyboard'),
          onVoice: () => debugPrint('Voice'),
          onRetry: () => debugPrint('Retry'),
          onMenu: () => debugPrint('Menu'),
          onPointerMove: (v) => debugPrint('Move: $v'),
          onScroll: (v) => debugPrint('Scroll: $v'),
          onClick: (v) => debugPrint('Right click: $v'),
          onAirMouseChanged: (v) => debugPrint('Air mouse: $v'),
        );
      },
    ),
  );
}
