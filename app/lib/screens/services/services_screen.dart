import 'dart:convert';
import 'dart:typed_data';

import 'package:app_core/services_registry.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/mpc_service.dart';

/// Browse the cosigner's contract template directory (CosignerID -> [template,
/// VerifyingShare]) and create a contract WITH a chosen author as the receiver. The
/// "Incoming" action picks up any contract shares waiting in this wallet's inbox.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  bool _loading = true;
  String? _error;
  String? _creatingId; // contractIdHex currently being created

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadContracts());
  }

  Future<void> _loadContracts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<MpcService>().fetchContracts();
    } catch (e) {
      _error = 'Could not reach the contract directory: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create(DirectoryContract c) async {
    final mpc = context.read<MpcService>();
    // For a template, collect the author's typed config from its published schema first.
    List<(String, ConfigValue)>? config;
    if (c.isTemplate) {
      config = await _collectConfig(c);
      if (config == null) return; // cancelled
    }
    setState(() {
      _creatingId = c.contractIdHex;
      _error = null;
    });
    try {
      final spk = config == null
          ? await mpc.createContractWith(c)
          : await mpc.createContractFromTemplate(c, config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created contract eVTXO ${spk.substring(0, 16)}…')),
        );
      }
    } catch (e) {
      _error = 'Create failed: $e';
    }
    if (mounted) setState(() => _creatingId = null);
  }

  /// Show a schema-driven form for a template's typed variables and return the encoded config
  /// (or null if cancelled). Schema JSON: `[{"name":..,"type":"bytes"|"u64"|"string"}]`.
  Future<List<(String, ConfigValue)>?> _collectConfig(DirectoryContract c) async {
    final fields = <Map<String, dynamic>>[];
    try {
      for (final e in (jsonDecode(c.schema) as List)) {
        fields.add(e as Map<String, dynamic>);
      }
    } catch (_) {}
    final controllers = {
      for (final f in fields) f['name'] as String: TextEditingController()
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Configure ${c.name}',
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: fields.map((f) {
            final name = f['name'] as String;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: TextField(
                key: Key('cfg_$name'),
                controller: controllers[name],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: '$name (${f['type']})',
                  labelStyle: const TextStyle(color: Colors.white54),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              key: const Key('cfgConfirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create')),
        ],
      ),
    );
    if (ok != true) return null;
    return [
      for (final f in fields)
        (
          f['name'] as String,
          _toConfigValue(f['type'] as String, controllers[f['name']]!.text),
        )
    ];
  }

  ConfigValue _toConfigValue(String type, String input) {
    switch (type) {
      case 'u64':
        return CfgU64(int.tryParse(input.trim()) ?? 0);
      case 'string':
        return CfgString(input);
      case 'bytes':
      default:
        return CfgBytes(Uint8List.fromList(utf8.encode(input)));
    }
  }

  Future<void> _pickUp() async {
    try {
      final n = await context.read<MpcService>().pickUpContractShares();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(n == 0 ? 'No incoming contract shares' : 'Picked up $n contract share(s)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Pick-up failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mpc = context.watch<MpcService>();
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Contracts'),
        actions: [
          IconButton(
            key: const Key('pickUpShares'),
            icon: const Icon(Icons.inbox),
            tooltip: 'Pick up incoming shares',
            onPressed: _pickUp,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadContracts,
        child: _buildBody(mpc),
      ),
      bottomNavigationBar: _nav(context),
    );
  }

  Widget _buildBody(MpcService mpc) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(children: [
        const SizedBox(height: 80),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center),
          ),
        ),
      ]);
    }
    if (mpc.contracts.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 80),
        Center(child: Text('No published contracts', style: TextStyle(color: Colors.white54))),
      ]);
    }
    return ListView(
      children: mpc.contracts.map((c) {
        final busy = _creatingId == c.contractIdHex;
        final author = c.authorVkHex.length >= 12
            ? '${c.authorVkHex.substring(0, 12)}…'
            : c.authorVkHex;
        return Card(
          color: const Color(0xFF1E1E1E),
          child: ListTile(
            key: Key('contract_${c.contractIdHex}'),
            title: Text(c.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text('${c.description}\nby $author',
                style: const TextStyle(color: Colors.white38)),
            isThreeLine: true,
            trailing: busy
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : ElevatedButton(
                    key: Key('createContract_${c.contractIdHex}'),
                    onPressed: _creatingId != null ? null : () => _create(c),
                    child: const Text('Create'),
                  ),
          ),
        );
      }).toList(),
    );
  }

  Widget _nav(BuildContext context) => BottomNavigationBar(
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        currentIndex: 3,
        onTap: (index) {
          if (index == 0) context.go('/');
          if (index == 1) context.go('/ark');
          if (index == 2) context.push('/spending/send');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.account_tree), label: 'Ark'),
          BottomNavigationBarItem(icon: Icon(Icons.send), label: 'Send'),
          BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Contracts'),
        ],
      );
}
