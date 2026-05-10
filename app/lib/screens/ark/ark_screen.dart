import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app/services/mpc_service.dart';
import 'package:protocol/protocol.dart';

class ArkScreen extends StatelessWidget {
  const ArkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mpcService = context.watch<MpcService>();
    final arkBalance = mpcService.arkBalance;
    final arkTxs = mpcService.arkTransactions;
    final arkAvailable = mpcService.arkAvailable;

    final balanceBtc = arkBalance.toDouble() / 100000000;
    final balanceUsd = balanceBtc * 65000;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ark',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            key: const Key('arkRefreshBtn'),
            icon: const Icon(Icons.refresh),
            onPressed: () => mpcService.refreshVtxos(),
          ),
        ],
      ),
      body: SafeArea(
        child: !arkAvailable
            ? _buildUnavailable(context)
            : Column(
                children: [
                  const SizedBox(height: 24),
                  _buildArkBalanceCard(context, arkBalance, balanceUsd),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Transactions',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: arkTxs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long_outlined,
                                    size: 48, color: Colors.white24),
                                const SizedBox(height: 12),
                                Text(
                                  'No transactions yet',
                                  style:
                                      GoogleFonts.inter(color: Colors.white38),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Board on-chain funds to get started',
                                  style: GoogleFonts.inter(
                                      color: Colors.white24, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: arkTxs.length,
                            itemBuilder: (context, index) {
                              final tx = arkTxs[arkTxs.length - 1 - index];
                              return _buildTransactionItem(tx);
                            },
                          ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildUnavailable(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              'Ark Not Available',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The server is not connected to an ASP.\nArk features require an ASP connection.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArkBalanceCard(
      BuildContext context, BigInt balance, double usdValue) {
    final balanceFormatter = NumberFormat("#,##0", "en_US");
    final usdFormatter = NumberFormat.currency(symbol: "\$");

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A237E),
            Colors.grey[900]!,
          ],
        ),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ark Balance',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Off-chain',
                  style: GoogleFonts.inter(
                    color: Colors.blueAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${balanceFormatter.format(balance.toInt())} Sats',
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            usdFormatter.format(usdValue),
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.white38,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  widgetKey: const Key('arkSendBtn'),
                  icon: Icons.arrow_upward,
                  label: 'Send',
                  onTap: () => context.push('/ark/send'),
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  widgetKey: const Key('arkReceiveBtn'),
                  icon: Icons.arrow_downward,
                  label: 'Receive',
                  onTap: () => context.push('/ark/receive'),
                  isPrimary: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  widgetKey: const Key('arkBoardBtn'),
                  icon: Icons.login,
                  label: 'Board',
                  onTap: () => context.push('/ark/board'),
                  isPrimary: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    Key? widgetKey,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      key: widgetKey,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.white : Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isPrimary ? Colors.black : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isPrimary ? Colors.black : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(ArkTransactionSummary tx) {
    final amount = tx.amountSats.toInt();
    final isIncoming = amount >= 0;
    final absAmount = amount.abs();
    final formatter = NumberFormat("#,##0", "en_US");

    String title;
    switch (tx.txType) {
      case 'board':
        title = 'Boarded (UTXO → VTXO)';
        break;
      case 'send':
        title = 'Sent';
        break;
      case 'receive':
        title = 'Received';
        break;
      case 'settle':
        title = 'Refreshed (VTXO)';
        break;
      default:
        title = tx.txType;
    }

    final date = tx.timestamp > 0
        ? DateFormat.yMMMd().add_jm().format(
            DateTime.fromMillisecondsSinceEpoch(tx.timestamp.toInt() * 1000))
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isIncoming
                  ? Colors.green.withOpacity(0.1)
                  : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncoming ? Colors.greenAccent : Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                Text(
                  date,
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isIncoming ? '+' : '-'}${formatter.format(absAmount)} Sats',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: isIncoming ? Colors.greenAccent : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF1E1E1E),
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white38,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      currentIndex: 1,
      onTap: (index) {
        if (index == 0) context.go('/');
        if (index == 2) context.push('/spending/send');
        if (index == 3) context.push('/policies');
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet_outlined),
          activeIcon: Icon(Icons.account_balance_wallet),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_tree_outlined),
          activeIcon: Icon(Icons.account_tree),
          label: 'Ark',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.send_outlined),
          activeIcon: Icon(Icons.send),
          label: 'Send',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.shield_outlined),
          activeIcon: Icon(Icons.shield),
          label: 'Policies',
        ),
      ],
    );
  }
}
