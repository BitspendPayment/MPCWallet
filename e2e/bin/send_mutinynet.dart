import 'package:e2e/mutinynet_funder.dart';

void main() async {
  const funderKey = 'e5fd0d96fd36e8237a557368c7f9f43cecb5c7d90c5970cc51d5ea3c0e2c3daa';
  const toAddress = 'tb1p4ujkwagafgjhcc3tjgaa7rlkw32wdtqwcv2j9744nq7z46d2xt5s5fgz60';
  const amount = 100000;

  final funder = MutinyNetFunder(funderKey);
  await funder.connect();

  final balance = await funder.getBalanceSats();
  print('Funder balance: $balance sats');

  if (balance < amount + 500) {
    print('Insufficient balance');
    await funder.close();
    return;
  }

  final txid = await funder.sendToAddress(toAddress, amount);
  print('Sent $amount sats to $toAddress');
  print('txid: $txid');

  await funder.close();
}
