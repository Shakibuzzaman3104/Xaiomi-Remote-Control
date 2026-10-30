/**
 * @author Shakib
 * @since 30/10/26
 */
part of 'transfer_page.dart';

class _TransferJobTile extends StatelessWidget {
  const _TransferJobTile({
    required this.job,
    required this.onCancel,
    required this.onRetry,
    required this.onOpen,
  });
  final TransferJob job;
  final VoidCallback onCancel, onRetry, onOpen;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final running = job.status == TransferStatus.running;
    final queued = job.status == TransferStatus.queued;
    final status = switch (job.status) {
      TransferStatus.queued => 'Queued',
      TransferStatus.running =>
        job.direction == TransferDirection.install
            ? 'Installing…'
            : '${(job.progress * 100).round()}%',
      TransferStatus.done =>
        job.direction == TransferDirection.install
            ? 'Installed'
            : job.direction == TransferDirection.toPhone
            ? 'Saved'
            : 'Sent',
      TransferStatus.failed => job.error ?? 'Failed',
      TransferStatus.cancelled => 'Cancelled',
    };
    return _TransferCard(
      color: c.appTile,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _TransferIcon(job.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTextTheme.titleSmall,
                  ),
                  Text(
                    '${_size(job.size)} · $status',
                    style: TextStyle(
                      color: job.status == TransferStatus.failed
                          ? c.danger
                          : c.muted,
                    ),
                  ),
                  if (running)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: LinearProgressIndicator(
                        value: job.progress,
                        backgroundColor: c.progressTrack,
                      ),
                    ),
                ],
              ),
            ),
            if (running || queued)
              IconButton(
                tooltip: 'Cancel',
                onPressed: onCancel,
                icon: const Icon(Icons.close),
              )
            else if (job.status == TransferStatus.failed ||
                job.status == TransferStatus.cancelled)
              TextButton(onPressed: onRetry, child: const Text('Retry'))
            else if (job.resultPath != null)
              TextButton(
                onPressed: onOpen,
                child: Text(
                  job.direction == TransferDirection.toPhone
                      ? 'Open'
                      : 'Open on TV',
                ),
              )
            else
              Icon(Icons.check_circle, color: c.primary),
          ],
        ),
      ),
    );
  }
}
