/**
 * @author Shakib
 * @since 30/10/26
 */
part of 'transfer_page.dart';

class _SendTab extends StatelessWidget {
  const _SendTab({
    super.key,
    required this.text,
    required this.isUrl,
    required this.jobs,
    required this.onPick,
    required this.onChanged,
    required this.onCopy,
    required this.onType,
    required this.onPaste,
    required this.onOpenText,
    required this.onClear,
    required this.onCancel,
    required this.onRetry,
    required this.onOpenJob,
  });
  final TextEditingController text;
  final bool isUrl;
  final List<TransferJob> jobs;
  final VoidCallback onPick,
      onChanged,
      onCopy,
      onType,
      onPaste,
      onOpenText,
      onClear;
  final ValueChanged<String> onCancel, onRetry;
  final ValueChanged<TransferJob> onOpenJob;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      key: const ValueKey('send'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        SpringTapFeedback(
          child: InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(16),
            child: CustomPaint(
              painter: _DashedBorder(c.primary),
              child: SizedBox(
                height: 190,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _TransferIcon('upload'),
                    const SizedBox(height: 12),
                    Text(
                      'Choose files',
                      style: context.appTextTheme.titleLarge?.copyWith(
                        color: c.onSurfaceStrong,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Photos, videos, APKs, documents',
                      style: TextStyle(color: c.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _TransferCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Send text', style: context.appTextTheme.titleSmall),
                const SizedBox(height: 10),
                TextField(
                  controller: text,
                  minLines: 3,
                  maxLines: 5,
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    hintText: 'Paste a link or note...',
                    filled: true,
                    fillColor: c.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilledButton(
                      onPressed: onCopy,
                      child: const Text('Copy to TV clipboard'),
                    ),
                    OutlinedButton(
                      onPressed: onType,
                      child: const Text('Type on TV'),
                    ),
                    TextButton(
                      onPressed: onPaste,
                      child: const Text('Paste from TV'),
                    ),
                    if (isUrl)
                      TextButton(
                        onPressed: onOpenText,
                        child: const Text('Open on TV'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent',
                style: context.appTextTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (jobs.any(
              (j) =>
                  j.status == TransferStatus.done ||
                  j.status == TransferStatus.failed ||
                  j.status == TransferStatus.cancelled,
            ))
              TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ),
        if (jobs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Your transfers will appear here',
              style: TextStyle(color: c.muted),
            ),
          ),
        for (var i = 0; i < jobs.length; i++)
          SpringIn(
            delay: Duration(milliseconds: math.min(i, 7) * 30),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _TransferJobTile(
                job: jobs[i],
                onCancel: () => onCancel(jobs[i].id),
                onRetry: () => onRetry(jobs[i].id),
                onOpen: () => onOpenJob(jobs[i]),
              ),
            ),
          ),
      ],
    );
  }
}
