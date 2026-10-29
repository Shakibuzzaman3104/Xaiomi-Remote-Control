/**
 * @author Shakib
 * @since 29/10/26
 */
class KnownApp {
  const KnownApp({required this.package, required this.label, this.webLink});
  final String package;
  final String label;
  final String? webLink;
}

const knownApps = <KnownApp>[
  KnownApp(
    package: 'com.google.android.youtube.tv',
    label: 'YouTube',
    webLink: 'https://www.youtube.com',
  ),
  KnownApp(
    package: 'com.netflix.ninja',
    label: 'Netflix',
    webLink: 'https://www.netflix.com/browse',
  ),
  KnownApp(package: 'com.viewlift.hoichoi', label: 'Hoichoi'),
  KnownApp(package: 'com.banglalink.toffeetv', label: 'Toffee'),
  KnownApp(package: 'org.videolan.vlc', label: 'VLC'),
  KnownApp(package: 'com.plexapp.android', label: 'Plex'),
  KnownApp(package: 'in.startv.hotstar', label: 'Hotstar'),
  KnownApp(package: 'com.sonyliv', label: 'SonyLIV'),
  KnownApp(package: 'com.stremio.one', label: 'Stremio'),
  KnownApp(package: 'com.amazon.amazonvideo.livingroom', label: 'Prime Video'),
  KnownApp(package: 'com.android.vending', label: 'Play Store'),
  KnownApp(package: 'com.spotify.tv.android', label: 'Spotify'),
];
