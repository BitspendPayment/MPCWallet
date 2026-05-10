import 'dart:convert';

import 'package:http/http.dart' as http;

class RegtestHelper {
  final String rpcUrl;
  final String _user;
  final String _password;

  RegtestHelper({
    this.rpcUrl = 'http://10.0.2.2:18443/wallet/default',
    String user = 'admin1',
    String password = '123',
  })  : _user = user,
        _password = password;

  String get _authHeader =>
      'Basic ${base64Encode(utf8.encode('$_user:$_password'))}';

  Future<dynamic> _call(String method, [List<dynamic>? params]) async {
    final response = await http.post(
      Uri.parse(rpcUrl),
      headers: {
        'content-type': 'text/plain',
        'authorization': _authHeader,
      },
      body: jsonEncode({
        'jsonrpc': '1.0',
        'id': 'patrol',
        'method': method,
        'params': params ?? [],
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('RPC ${response.statusCode}: ${response.body}');
    }
    final body = jsonDecode(response.body);
    if (body['error'] != null) {
      throw Exception('RPC error: ${body['error']}');
    }
    return body['result'];
  }

  Future<void> ensureWalletLoaded(String name) async {
    try {
      await _call('createwallet', [name]);
    } catch (e) {
      final s = e.toString();
      if (!s.contains('Database already exists') &&
          !s.contains('already loaded') &&
          !s.contains('Wallet file verification failed')) {
        rethrow;
      }
      try {
        await _call('loadwallet', [name]);
      } catch (e2) {
        if (!e2.toString().contains('already loaded')) rethrow;
      }
    }
  }

  Future<String> getNewAddress({String type = 'bech32m'}) async =>
      await _call('getnewaddress', ['', type]);

  Future<List<String>> generateToAddress(int blocks, String address) async {
    final r = await _call('generatetoaddress', [blocks, address]);
    return (r as List).cast<String>();
  }

  Future<String> sendToAddress(String address, double amountBtc) async {
    return await _call('sendtoaddress', [address, amountBtc]);
  }

  Future<void> mineCoinsTo(String address,
      {int matureBlocks = 101}) async {
    await generateToAddress(matureBlocks, address);
  }
}
