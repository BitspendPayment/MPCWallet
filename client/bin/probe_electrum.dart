import 'package:bitcoin_base/bitcoin_base.dart';
// import 'package:bitcoin_base/services.dart';
// import 'package:bitcoin_base/providers.dart';

void main() {
  try {
    print(ElectrumSSLService);
  } catch (e) {
    print("ElectrumSSLService not found");
    // Try looking for generic SSLService?
  }
}

class MockApi extends ApiProvider {}

void main() {
  try {
    print(ElectrumSSLService);
  } catch (e) {
    print("ElectrumSSLService not found");
  }
  try {
    print(ElectrumProvider);
  } catch (e) {
    print("ElectrumProvider not found");
  }
  // api.getUtxo();
  // api.sendRawTransaction();
  try {
    print(ElectrumRequestScriptHashListUnspent);
  } catch (e) {
    print("ElectrumRequestScriptHashListUnspent not found");
  }
}
