import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:http/http.dart' as http;

/// A published contract template from the cosigner directory
/// (`GET {cosigner}/api/contracts`). The author's verifying key (the CosignerID) is
/// ALSO the receiver vk when you create a contract WITH that author.
class DirectoryContract {
  final Uint8List authorVk; // CosignerID = VerifyingShare (33B)
  final Uint8List contractId; // sha256(template wasm), 32B
  final String name;
  final String description;
  final String stubId; // content id of the provider stub (empty ⇒ no per-instance config)
  final String schema; // typed config schema JSON (the form fields), empty if none

  const DirectoryContract({
    required this.authorVk,
    required this.contractId,
    required this.name,
    required this.description,
    this.stubId = '',
    this.schema = '',
  });

  String get authorVkHex => hex.encode(authorVk);
  String get contractIdHex => hex.encode(contractId);
  bool get isTemplate => stubId.isNotEmpty;
}

/// A typed contract-config value the author sets for a template variable.
sealed class ConfigValue {
  const ConfigValue();
}

class CfgBytes extends ConfigValue {
  final Uint8List v;
  const CfgBytes(this.v);
}

class CfgU64 extends ConfigValue {
  final int v;
  const CfgU64(this.v);
}

class CfgString extends ConfigValue {
  final String v;
  const CfgString(this.v);
}

/// Encode the typed config as the KV blob the cosigner patches into the provider stub:
/// `[n: u16 LE]` then n × `[key_len: u8][key][type: u8][val_len: u16 LE][val]`
/// (type 0 = bytes, 1 = u64 LE, 2 = string). Must match the cosigner + provider stub format.
Uint8List encodeContractConfig(List<(String, ConfigValue)> entries) {
  final b = BytesBuilder();
  void u16(int n) => b.add([n & 0xff, (n >> 8) & 0xff]);
  u16(entries.length);
  for (final (key, val) in entries) {
    final kb = utf8.encode(key);
    b.addByte(kb.length);
    b.add(kb);
    final (int ty, List<int> vb) = switch (val) {
      CfgBytes(:final v) => (0, v),
      CfgU64(:final v) => (1, [for (var i = 0; i < 8; i++) (v >> (8 * i)) & 0xff]),
      CfgString(:final v) => (2, utf8.encode(v)),
    };
    b.addByte(ty);
    u16(vb.length);
    b.add(vb);
  }
  return b.toBytes();
}

/// Read-only client for the cosigner's contract template directory (peer model):
/// `CosignerID -> [Contract Template, VerifyingShare]`. The wallet browses published
/// templates, picks one, and creates a contract WITH that author as the receiver.
class ContractDirectory {
  final http.Client _http;

  ContractDirectory({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  String _base(String url) => url.replaceAll(RegExp(r'/+$'), '');

  /// Browse all published templates (`GET {cosigner}/api/contracts`).
  Future<List<DirectoryContract>> listContracts(String cosignerBase) async {
    final r =
        await _http.get(Uri.parse('${_base(cosignerBase)}/api/contracts'));
    if (r.statusCode != 200) {
      throw Exception('listContracts: HTTP ${r.statusCode}: ${r.body}');
    }
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    final list = (body['contracts'] as List? ?? const []);
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return DirectoryContract(
        authorVk:
            Uint8List.fromList(hex.decode(m['author_vk'] as String? ?? '')),
        contractId:
            Uint8List.fromList(hex.decode(m['contract_id'] as String? ?? '')),
        name: m['name'] as String? ?? 'contract',
        description: m['description'] as String? ?? '',
        stubId: m['stub_id'] as String? ?? '',
        schema: m['schema'] as String? ?? '',
      );
    }).toList();
  }

  /// Publish a contract template under [authorVkHex] (the CosignerID), so others can
  /// discover it and create a contract WITH this author
  /// (`POST {cosigner}/api/u/{authorVk}/contract/register-template`).
  Future<void> registerTemplate({
    required String cosignerBase,
    required String authorVkHex,
    required String contractIdHex,
    required Uint8List wasm,
    Uint8List? providerStubWasm,
    String schema = '',
    String name = '',
    String description = '',
  }) async {
    final r = await _http.post(
      Uri.parse(
          '${_base(cosignerBase)}/api/u/$authorVkHex/contract/register-template'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'contract_id': contractIdHex,
        'contract_wasm': hex.encode(wasm),
        'provider_stub_wasm':
            providerStubWasm == null ? '' : hex.encode(providerStubWasm),
        'schema': schema,
        'name': name,
        'description': description,
      }),
    );
    if (r.statusCode != 200) {
      throw Exception('registerTemplate: HTTP ${r.statusCode}: ${r.body}');
    }
  }

  /// The raw wasm for a published template
  /// (`GET {cosigner}/api/contracts/{id}/wasm`).
  Future<Uint8List> fetchWasm(String cosignerBase, String contractIdHex) async {
    final r = await _http.get(
        Uri.parse('${_base(cosignerBase)}/api/contracts/$contractIdHex/wasm'));
    if (r.statusCode != 200) {
      throw Exception('fetchWasm: HTTP ${r.statusCode}');
    }
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    return Uint8List.fromList(hex.decode(body['contract_wasm'] as String? ?? ''));
  }

  void close() => _http.close();
}
