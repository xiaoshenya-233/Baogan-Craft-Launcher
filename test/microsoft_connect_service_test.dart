import 'package:baogan_craft_launcher/services/network/microsoft_connect_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blank client ids fall back to the launcher client id', () {
    expect(defaultMicrosoftClientId, 'fcb9776-0d60-4879-984b-bb833bd55152');
    expect(MicrosoftConnectService.resolveClientId(null), defaultMicrosoftClientId);
    expect(MicrosoftConnectService.resolveClientId('   '), defaultMicrosoftClientId);
    expect(MicrosoftConnectService.resolveClientId(' custom-id '), 'custom-id');
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
