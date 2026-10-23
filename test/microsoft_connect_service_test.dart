import 'package:baogan_craft_launcher/services/network/microsoft_connect_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects a missing Azure client id without network access', () async {
    const service = MicrosoftConnectService();
    await expectLater(
      service.signIn(clientId: '   ', onDeviceCode: (_) {}),
      throwsA(
        isA<MicrosoftConnectException>().having(
          (error) => error.failure,
          'failure',
          MicrosoftConnectFailure.notConfigured,
        ),
      ),
    );
  });

  test('device code prompt exposes a readable expiry', () {
    const prompt = MicrosoftConnectDeviceCode(
      userCode: 'ABCD-EFGH',
      verificationUri: 'https://microsoft.com/devicelogin',
      expiresIn: 900,
    );
    expect(prompt.expiresInDuration.inMinutes, 15);
  });
}
