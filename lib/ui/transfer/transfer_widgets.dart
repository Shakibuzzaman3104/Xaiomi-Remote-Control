/**
 * @author Shakib
 * @since 30/10/26
 */
part of 'transfer_page.dart';

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.child, this.color});
  final Widget child;
  final Color? color;
  @override
  Widget build(BuildContext context) => Material(
    color: color ?? context.colors.surfaceContainer,
    borderRadius: BorderRadius.circular(AppShapes.card),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _TransferIcon extends StatelessWidget {
  const _TransferIcon(this.name, {this.folder = false});
  final String name;
  final bool folder;
  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: context.colors.okButton,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(
      folder ? Icons.folder_rounded : _fileIcon(name),
      color: context.colors.primary,
    ),
  );
}

String _size(int bytes) {
  if (bytes >= 1073741824) {
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}

IconData _fileIcon(String name) {
  final ext = name.split('.').last.toLowerCase();
  if (name == 'upload') return Icons.upload;
  if (name == 'storage') return Icons.storage;
  if (['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(ext)) return Icons.image;
  if (['mp4', 'mkv', 'avi', 'webm'].contains(ext)) return Icons.play_arrow;
  if (ext == 'apk') return Icons.android;
  if (['mp3', 'wav', 'm4a'].contains(ext)) return Icons.music_note;
  return Icons.insert_drive_file_outlined;
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 10) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 6, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => oldDelegate.color != color;
}
