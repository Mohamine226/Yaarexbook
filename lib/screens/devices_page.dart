import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// Appareils connectés au compte. Plusieurs appareils peuvent l'être en même temps.
class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  List<Device>? _devices;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.devices();
      if (mounted) setState(() {
        _devices = d;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _revoke(Device d) async {
    final ok = await confirm(context, title: 'Déconnecter cet appareil ?', message: d.name, action: 'Déconnecter', danger: true);
    if (!ok) return;
    try {
      await Api.revokeDevice(d.id);
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _revokeOthers() async {
    final ok = await confirm(
      context,
      title: 'Déconnecter les autres appareils ?',
      message: 'Seul cet appareil restera connecté.',
      action: 'Tout déconnecter',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.revokeOtherDevices();
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = _devices;
    return Scaffold(
      appBar: AppBar(title: const Text('Mes appareils')),
      body: devices == null
          ? (_error != null ? ErrorState(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final d in devices)
                    Card(
                      child: ListTile(
                        leading: Icon(d.current ? Icons.smartphone : Icons.devices_other),
                        title: Text(d.name + (d.current ? ' (cet appareil)' : '')),
                        subtitle: Text('Dernière activité : ${timeAgo(d.lastSeen)}'),
                        trailing: d.current
                            ? null
                            : IconButton(icon: const Icon(Icons.logout), tooltip: 'Déconnecter', onPressed: () => _revoke(d)),
                      ),
                    ),
                  if (devices.length > 1) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _revokeOthers, child: const Text('Déconnecter tous les autres appareils')),
                  ],
                ],
              ),
            ),
    );
  }
}
