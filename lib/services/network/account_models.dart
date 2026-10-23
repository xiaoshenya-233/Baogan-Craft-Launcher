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
    return UserAccount(
      id: id.trim(),
      name: name.trim(),
      uuid: uuid.trim(),
      type: AccountTypeInfo.fromName(raw['type'] as String?),
      javaAgent: javaAgent is String && javaAgent.trim().isNotEmpty
          ? javaAgent.trim()
          : null,
    );
  }

  UserAccount copyWith({
    String? name,
    String? uuid,
    String? accessToken,
    String? refreshToken,
    String? javaAgent,
  }) => UserAccount(
    id: id,
    name: name ?? this.name,
    uuid: uuid ?? this.uuid,
    type: type,
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    javaAgent: javaAgent ?? this.javaAgent,
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
    );
  }
}
