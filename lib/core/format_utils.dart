/// Formats a byte count with binary units (1 KB = 1024 B).
///
/// Shared by the download queue, the download pages, the log viewer and the
/// version models so every progress label uses the same scale.
String formatByteSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(gb < 10 ? 2 : 1)} GB';
}
