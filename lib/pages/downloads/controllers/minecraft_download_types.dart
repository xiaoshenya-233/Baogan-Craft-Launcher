import '../../../services/network/api_service.dart';

enum MinecraftReleaseCategory {
  release('正式版'),
  preview('预览版'),
  old('远古版'),
  aprilFools('愚人节版');

  const MinecraftReleaseCategory(this.label);

  final String label;

  static MinecraftReleaseCategory? forVersion(MinecraftCatalogVersion version) {
    final id = version.id.toLowerCase();
    if (RegExp(r'\d{2}w14').hasMatch(id) ||
        id == '23w13a_or_b' ||
        id == '3d shareware v1.34' ||
        id == '1.rv-pre1') {
      return MinecraftReleaseCategory.aprilFools;
    }
    return switch (version.type) {
      'release' => MinecraftReleaseCategory.release,
      'snapshot' => MinecraftReleaseCategory.preview,
      'old_alpha' || 'old_beta' => MinecraftReleaseCategory.old,
      _ => null,
    };
  }
}

enum MinecraftLoader {
  forge('Forge', 'forge'),
  neoForge('NeoForge', 'neoforge'),
  fabric('Fabric', 'fabric'),
  optiFine('OptiFine', 'optifine');

  const MinecraftLoader(this.label, this.apiName);

  final String label;
  final String apiName;
}
