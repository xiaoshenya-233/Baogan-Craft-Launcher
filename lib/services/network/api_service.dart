// Public entry point of the launcher network layer.
//
// The implementation is split by platform:
// * `models.dart` - data models, enums and shared parsing helpers
// * `modrinth_service.dart` - Modrinth and Mojang catalog requests
// * `curseforge_service.dart` - CurseForge requests
export 'models.dart';
export 'modrinth_service.dart';
export 'curseforge_service.dart';
