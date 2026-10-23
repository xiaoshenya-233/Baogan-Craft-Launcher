import 'package:mcid_connect/mcid_connect.dart' as mcid;

import 'auth_service.dart';

/// Device-code instructions surfaced by [MicrosoftConnectService].
class MicrosoftConnectDeviceCode {
  const MicrosoftConnectDeviceCode({
    required this.userCode,
    required this.verificationUri,
    required this.expiresIn,
  });

  final String userCode;
  final String verificationUri;
  final int expiresIn;

  Duration get expiresInDuration => Duration(seconds: expiresIn);
}

/// Why a Microsoft sign-in failed, so the UI can show a friendly message.
enum MicrosoftConnectFailure {
  notConfigured,
  cancelledOrExpired,
  noMinecraftProfile,
  tokenMissing,
  unknown,
}

class MicrosoftConnectException implements Exception {
  const MicrosoftConnectException(this.failure, this.message);

  final MicrosoftConnectFailure failure;
  final String message;

  @override
  String toString() => message;
}

/// Microsoft / Xbox Live / Minecraft login built on the `mcid_connect` package.
///
/// The Azure application must be registered as a public client (mobile &
/// desktop) with the `XboxLive.signin` and `offline_access` scopes.
class MicrosoftConnectService {
  const MicrosoftConnectService({
    this.redirectUri = 'http://localhost:3000',
    this.scopes = const <String>['XboxLive.signin', 'offline_access'],
  });

  final String redirectUri;
  final List<String> scopes;

  /// Runs the device-code flow and returns the Minecraft identity.
  ///
  /// [onDeviceCode] fires as soon as Microsoft issues the code so the caller can
  /// display it; polling continues in the background until the player finishes.
  Future<AuthIdentity> signIn({
    required String clientId,
    required void Function(MicrosoftConnectDeviceCode prompt) onDeviceCode,
  }) async {
    final normalizedClientId = clientId.trim();
    if (normalizedClientId.isEmpty) {
      throw const MicrosoftConnectException(
        MicrosoftConnectFailure.notConfigured,
        '请先在设置中填写 Azure 应用程序（客户端）ID，并开启“允许公共客户端流”。',
      );
    }

    final authService = mcid.AuthService(
      clientId: normalizedClientId,
      redirectUri: redirectUri,
      scopes: scopes,
      onGetDeviceCode: (response) {
        onDeviceCode(
          MicrosoftConnectDeviceCode(
            userCode: response.userCode,
            verificationUri: response.verificationUri,
            expiresIn: response.expiresIn,
          ),
        );
      },
    );

    final bool success;
    try {
      success = await authService.startAuthenticationFlow(useDeviceCode: true);
    } on Object catch (error) {
      throw MicrosoftConnectException(
        MicrosoftConnectFailure.unknown,
        'Microsoft 登录中断：$error',
      );
    }
    if (!success) {
      throw const MicrosoftConnectException(
        MicrosoftConnectFailure.cancelledOrExpired,
        '登录未完成：设备码可能已过期、登录被取消，或网络连接失败。请重新尝试。',
      );
    }

    final bool hasProfile;
    try {
      hasProfile = await authService.hasMinecraftProfile();
    } on Object catch (error) {
      throw MicrosoftConnectException(
        MicrosoftConnectFailure.noMinecraftProfile,
        'Microsoft 账号已登录，但无法读取 Minecraft 档案：$error',
      );
    }
    if (!hasProfile) {
      throw const MicrosoftConnectException(
        MicrosoftConnectFailure.noMinecraftProfile,
        '该 Microsoft 账号还没有 Minecraft 档案：请确认已购买游戏并在官方启动器创建过角色。',
      );
    }

    final profile = await authService.getMinecraftProfile();
    final token = authService.minecraftToken?.trim() ?? '';
    if (profile == null || token.isEmpty) {
      throw const MicrosoftConnectException(
        MicrosoftConnectFailure.tokenMissing,
        '登录成功但未能获取 Minecraft 访问令牌，请稍后重试。',
      );
    }

    return AuthIdentity(
      name: profile.name,
      uuid: profile.id,
      accessToken: token,
      userType: 'msa',
    );
  }
}
