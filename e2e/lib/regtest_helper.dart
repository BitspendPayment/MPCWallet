import 'dart:convert';
import 'package:http/http.dart' as http;

class RegtestHelper {
  final String rpcUrl;
  String _user = 'admin';
  String _password = 'admin';

  RegtestHelper({this.rpcUrl = "http://127.0.0.1:18443"});

  String get _authHeader {
    return 'Basic ' + base64Encode(utf8.encode('$_user:$_password'));
  }

  Future<dynamic> _call(String method, [List<dynamic>? params]) async {
    final payload = {
      'jsonrpc': '1.0',
      'id': 'curltest',
      'method': method,
      'params': params ?? []
    };

    final response = await http.post(
      Uri.parse(rpcUrl),
      headers: {
        'content-type': 'text/plain',
        'authorization': _authHeader,
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('RPC Error: ${response.statusCode} - ${response.body}');
    }

    final body = jsonDecode(response.body);
    if (body['error'] != null) {
      throw Exception('RPC Error Body: ${body['error']}');
    }

    return body['result'];
  }

  /// Generates a new address for the miner/admin wallet.
  Future<String> getNewAddress() async {
    return await _call('getnewaddress');
  }

  /// Mines [blocks] blocks to [address].
  Future<List<String>> generateToAddress(int blocks, String address) async {
    final result = await _call('generatetoaddress', [blocks, address]);
    return (result as List).cast<String>();
  }

  /// Sends [amount] BTC to [address].
  Future<String> sendToAddress(String address, double amount) async {
    return await _call('sendtoaddress', [address, amount]);
  }

  /// Gets raw transaction hex (and verbose info if needed).
  Future<dynamic> getRawTransaction(String txId) async {
    return await _call('getrawtransaction', [txId, true]);
  }

  /// Gets Mempool entry.
  Future<dynamic> getMempoolEntry(String txId) async {
    return await _call('getmempoolentry', [txId]);
  }

  /// Sends raw transaction hex.
  Future<String> sendRawTransaction(String hex) async {
    return await _call('sendrawtransaction', [hex]);
  }

  /// Scans the UTXO set for an address.
  /// Note: This is an expensive call on mainnet, but fine for regtest.
  Future<List<Map<String, dynamic>>> scanUtxos(String address) async {
    final result = await _call('scantxoutset', [
      'start',
      [
        {'desc': 'addr($address)'}
      ]
    ]);
    return (result['unspents'] as List).cast<Map<String, dynamic>>();
  }
}
