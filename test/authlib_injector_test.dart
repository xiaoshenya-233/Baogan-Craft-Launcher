import 'package:baogan_craft_launcher/services/launcher/authlib_injector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('agent argument joins the jar path and the server', () {
    expect(
      AuthlibInjector.agentArgument(
        r'C:\BGCL\runtime\authlib-injector.jar',
        'https://littleskin.cn/api/yggdrasil',
      ),
      r'C:\BGCL\runtime\authlib-injector.jar=https://littleskin.cn/api/yggdrasil',
    );
  });

  test('server can be recovered from a stored agent argument', () {
    expect(
      AuthlibInjector.serverFromAgent(
        r'C:\BGCL\runtime\authlib-injector.jar=https://example.com/api/yggdrasil',
      ),
      'https://example.com/api/yggdrasil',
    );
    expect(AuthlibInjector.serverFromAgent(null), isNull);
    expect(AuthlibInjector.serverFromAgent('no-separator'), isNull);
    expect(AuthlibInjector.serverFromAgent('jar='), isNull);
  });
}
