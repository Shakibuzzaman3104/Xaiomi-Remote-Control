/**
 * @author Shakib
 * @since 30/10/26
 */
part of 'transfer_page.dart';

class _FileActionsSheet extends StatelessWidget {
  const _FileActionsSheet({
    required this.entry,
    required this.onSave,
    required this.onOpen,
    required this.onInstall,
    required this.onDelete,
  });
  final AdbFileEntry entry;
  final VoidCallback onSave, onOpen, onInstall, onDelete;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: _TransferIcon(entry.name),
              title: Text(entry.name),
              subtitle: Text(_size(entry.size)),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Save to phone'),
              onTap: onSave,
            ),
            ListTile(
              leading: const Icon(Icons.tv_outlined),
              title: const Text('Open on TV'),
              onTap: onOpen,
            ),
            if (entry.name.toLowerCase().endsWith('.apk'))
              ListTile(
                leading: const Icon(Icons.install_mobile_outlined),
                title: const Text('Install'),
                onTap: onInstall,
              ),
            Divider(color: context.colors.subtleOutline),
            ListTile(
              leading: Icon(Icons.delete_outline, color: context.colors.danger),
              title: Text(
                'Delete',
                style: TextStyle(color: context.colors.danger),
              ),
              onTap: onDelete,
            ),
          ],
        ),
      ),
    ),
  );
}
