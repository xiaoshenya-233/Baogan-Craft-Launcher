import 'dart:io';

import 'package:path/path.dart' as p;

/// Joins [part] onto [base] with the platform path separator.
///
/// Every launcher path is a directory plus a relative child
/// (`versions/<id>`, `libraries/<group>/<artifact>.jar`, ...). Keeping one
/// implementation removes the four hand-written string concatenations that
/// used to exist in the installer, launcher, models and home page.
String joinPath(String base, String part) =>
    p.join(base, part.replaceAll('/', p.separator));

/// Whether [path] is strictly inside [directory] (never equal to it).
///
/// Windows paths compare case-insensitively so `C:\BGCL` and `c:\bgcl`
/// are treated as the same root. Used before any recursive delete.
bool isPathInside(String path, String directory) {
  var target = p.normalize(p.absolute(path.trim()));
  var root = p.normalize(p.absolute(directory.trim()));
  if (root.isEmpty || root == p.separator) return false;
  if (Platform.isWindows) {
    target = target.toLowerCase();
    root = root.toLowerCase();
  }
  return p.isWithin(root, target);
}
