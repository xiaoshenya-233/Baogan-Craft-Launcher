import 'auth_service.dart';

/// Kind of account stored by the launcher.
enum AccountType { offline, microsoft, thirdParty }

extension AccountTypeInfo on AccountType {
  String get label => switch (this) {
    AccountType.offline => '本地档案',
    AccountType.microsoft => 'Microsoft 正版',
    AccountType.thirdParty => '第三方验证',
  };

  AuthMode get authMode => switch (this) {
    AccountType.offline => AuthMode.offline,
    AccountType.microsoft => AuthMode.microsoft,
    AccountType.thirdParty => AuthMode.thirdParty,
  };

  /// `userType` written into launch arguments.
  String get tokenUserType => switch (this) {
    AccountType.offline => 'legacy',
    AccountType.microsoft => 'msa',
    AccountType.thirdParty => 'mojang',
  };

  static AccountType fromName(String? name) => AccountType.values.firstWhere(
    (type) => type.name == name,
    orElse: () => AccountType.offline,
  );
}

/// One entry of the multi-account list.
///
/// `accessToken` / `refreshToken` are **runtime only**: [toJson] deliberately
/// omits them so they never reach the plaintext preferences file. Tokens live
/// in `flutter_secure_storage` keyed by [id].
class UserAccount {
  const UserAccount({
    required this.id,
    required this.name,
    required this.uuid,
    required this.type,
    this.accessToken = '',
    this.refreshToken = '',
    this.javaAgent,
    this.avatarUrl,
  });

  /// Stable identifier, e.g. `microsoft:<uuid>`.
  final String id;
  final String name;
  final String uuid;
  final AccountType type;

  /// Decrypted access token; empty when the secure store had no entry.
  final String accessToken;

  /// Decrypted Microsoft refresh token (optional).
  final String refreshToken;

  /// authlib-injector argument kept for third-party accounts.
  final String? javaAgent;

  /// Optional avatar image URL (Yggdrasil providers may expose one).
  final String? avatarUrl;

  /// Avatar URL to render, including a fallback for older third-party accounts
  /// that were saved before custom avatar support was added.
  String? get effectiveAvatarUrl {
    final server = _thirdPartyServer;
    if (type == AccountType.thirdParty && server != null) {
      final parsedServer = Uri.tryParse(server);
      if (parsedServer != null &&
          parsedServer.path.endsWith('/api/yggdrasil')) {
        // Blessing Skin (LittleSkin) renders avatars by player name. This also
        // repairs older stored URLs such as `/api/yggdrasil/avatar/<uuid>`.
        return thirdPartyAvatarUrl(server, uuid, playerName: name);
      }
    }
    final explicit = avatarUrl?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      final parsed = Uri.tryParse(explicit);
      const marker = '/api/yggdrasil/avatar/';
      if (parsed != null && parsed.hasScheme) {
        final index = parsed.path.indexOf(marker);
        if (index >= 0) {
          return '${parsed.scheme}://${parsed.authority}/avatar/'
              '${parsed.path.substring(index + marker.length)}';
        }
      }
      return explicit;
    }
    if (type != AccountType.thirdParty || server == null) return null;
    return thirdPartyAvatarUrl(server, uuid, playerName: name);
  }

  String? get _thirdPartyServer {
    if (type != AccountType.thirdParty) return null;
    final agent = javaAgent?.trim();
    if (agent == null || agent.isEmpty) return null;
    final separator = agent.indexOf('=');
    if (separator < 0 || separator + 1 >= agent.length) return null;
    final server = agent
        .substring(separator + 1)
        .trim()
        .replaceFirst(RegExp(r'/$'), '');
    final parsed = Uri.tryParse(server);
    if (parsed == null ||
        !parsed.hasScheme ||
        (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      return null;
    }
    return server;
  }

  bool get hasToken => accessToken.trim().isNotEmpty;

  bool get isOffline => type == AccountType.offline;

  static String buildId(AccountType type, String uuid) =>
      '${type.name}:${uuid.trim().toLowerCase()}';

  /// Non-sensitive metadata only — tokens are intentionally excluded.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'uuid': uuid,
    'type': type.name,
    if (javaAgent != null && javaAgent!.trim().isNotEmpty)
      'javaAgent': javaAgent,
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty)
      'avatarUrl': avatarUrl,
  };

  static UserAccount? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final uuid = raw['uuid'];
    if (id is! String || id.trim().isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;
    if (uuid is! String || uuid.trim().isEmpty) return null;
    final javaAgent = raw['javaAgent'];
    final avatarUrl = raw['avatarUrl'];
    return UserAccount(
      id: id.trim(),
      name: name.trim(),
      uuid: uuid.trim(),
      type: AccountTypeInfo.fromName(raw['type'] as String?),
      javaAgent: javaAgent is String && javaAgent.trim().isNotEmpty
          ? javaAgent.trim()
          : null,
      avatarUrl: avatarUrl is String && avatarUrl.trim().isNotEmpty
          ? avatarUrl.trim()
          : null,
    );
  }

  UserAccount copyWith({
    String? name,
    String? uuid,
    String? accessToken,
    String? refreshToken,
    String? javaAgent,
    String? avatarUrl,
  }) => UserAccount(
    id: id,
    name: name ?? this.name,
    uuid: uuid ?? this.uuid,
    type: type,
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    javaAgent: javaAgent ?? this.javaAgent,
    avatarUrl: avatarUrl ?? this.avatarUrl,
  );

  /// Builds the identity passed to the launcher for this account.
  AuthIdentity toIdentity() => AuthIdentity(
    name: name,
    uuid: uuid,
    accessToken: isOffline ? '0' : accessToken,
    userType: type.tokenUserType,
    javaAgent: javaAgent,
  );

  /// Converts a freshly authenticated identity into an account entry.
  static UserAccount fromIdentity(AuthIdentity identity) {
    final type = switch (identity.userType) {
      'msa' => AccountType.microsoft,
      'mojang' => AccountType.thirdParty,
      _ => AccountType.offline,
    };
    return UserAccount(
      id: buildId(type, identity.uuid),
      name: identity.name,
      uuid: identity.uuid,
      type: type,
      javaAgent: identity.javaAgent,
      avatarUrl: identity.avatarUrl,
    );
  }
}
