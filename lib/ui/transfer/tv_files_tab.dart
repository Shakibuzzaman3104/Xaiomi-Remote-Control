/**
 * @author Shakib
 * @since 30/10/26
 */
part of 'transfer_page.dart';

class _TvFilesTab extends StatelessWidget {
  const _TvFilesTab({
    super.key,
    required this.path,
    required this.entries,
    required this.storage,
    required this.error,
    required this.onLoad,
    required this.onNavigate,
    required this.onActions,
  });
  final String path;
  final List<AdbFileEntry>? entries;
  final ({int free, int total})? storage;
  final Object? error;
  final Future<void> Function() onLoad;
  final ValueChanged<String> onNavigate;
  final ValueChanged<AdbFileEntry> onActions;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final parts = path
        .substring('/sdcard'.length)
        .split('/')
        .where((p) => p.isNotEmpty)
        .toList();
    return RefreshIndicator(
      onRefresh: onLoad,
      child: ListView(
        key: const ValueKey('files'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => onNavigate('/sdcard'),
                  icon: const Icon(Icons.storage),
                  label: const Text('Internal storage'),
                ),
                for (var i = 0; i < parts.length; i++) ...[
                  const Icon(Icons.chevron_right),
                  TextButton(
                    onPressed: () =>
                        onNavigate('/sdcard/${parts.take(i + 1).join('/')}'),
                    child: Text(parts[i]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (storage != null)
            _TransferCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const _TransferIcon('storage'),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_size(storage!.free)} free of ${_size(storage!.total)}',
                            style: context.appTextTheme.titleSmall,
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: storage!.total > 0
                                ? (1 - storage!.free / storage!.total).clamp(
                                    0.0,
                                    1.0,
                                  )
                                : 0,
                            backgroundColor: c.progressTrack,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (error != null)
            Center(
              child: Column(
                children: [
                  const Text("Couldn't load this folder"),
                  TextButton(onPressed: onLoad, child: const Text('Retry')),
                ],
              ),
            )
          else if (entries == null)
            for (var i = 0; i < 4; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: _TransferCard(child: SizedBox(height: 72)),
              )
          else if (entries!.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('This folder is empty')),
            )
          else
            for (var i = 0; i < entries!.length; i++)
              SpringIn(
                delay: Duration(milliseconds: math.min(i, 7) * 30),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FileRow(
                    entry: entries![i],
                    onTap: () => entries![i].isDirectory
                        ? onNavigate('$path/${entries![i].name}')
                        : onActions(entries![i]),
                    onActions: () => onActions(entries![i]),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.entry,
    required this.onTap,
    required this.onActions,
  });
  final AdbFileEntry entry;
  final VoidCallback onTap, onActions;
  @override
  Widget build(BuildContext context) => SpringTapFeedback(
    child: _TransferCard(
      color: context.colors.appTile,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: _TransferIcon(entry.name, folder: entry.isDirectory),
        title: Text(entry.name, style: context.appTextTheme.titleSmall),
        subtitle: entry.isDirectory ? null : Text(_size(entry.size)),
        trailing: entry.isDirectory
            ? const Icon(Icons.chevron_right)
            : IconButton(
                tooltip: 'File actions',
                onPressed: onActions,
                icon: const Icon(Icons.more_vert),
              ),
        onTap: onTap,
      ),
    ),
  );
}
