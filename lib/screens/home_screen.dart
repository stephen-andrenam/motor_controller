import 'package:flutter/material.dart';
import '../services/ble_manager.dart';
import 'constant_mode_screen.dart';
import 'sweep_mode_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Motor Controller',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
      ),
      body: ListenableBuilder(
        listenable: BleManager.instance,
        builder: (context, _) {
          final ble = BleManager.instance;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ConnectionCard(ble: ble),
                const SizedBox(height: 16),
                _ConnectButton(ble: ble),
                const SizedBox(height: 48),
                Text(
                  'SELECT MODE',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                _ModeCard(
                  title: 'Constant Throttle',
                  description:
                      'Set a fixed throttle percentage. The motor holds\n'
                      'this speed after the command is sent.',
                  icon: Icons.speed,
                  color: const Color(0xFF00B4D8),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ConstantModeScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                _ModeCard(
                  title: 'Sweep Mode',
                  description:
                      'Define a throttle sweep profile. The ESP32 will\n'
                      'execute the sweep autonomously once submerged.',
                  icon: Icons.show_chart,
                  color: const Color(0xFF48CAE4),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SweepModeScreen()),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Commands are sent once — the device operates\n'
                    'independently after submerging.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Connection status card ────────────────────────────────────

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.ble});
  final BleManager ble;

  @override
  Widget build(BuildContext context) {
    final (dotColor, icon, label) = switch (ble.status) {
      BleStatus.connected  => (const Color(0xFF64FFDA), Icons.bluetooth_connected,  'Connected'),
      BleStatus.scanning   => (const Color(0xFFFFC107), Icons.bluetooth_searching,   'Scanning…'),
      BleStatus.connecting => (const Color(0xFFFFC107), Icons.bluetooth_searching,   'Connecting…'),
      BleStatus.error      => (const Color(0xFFFF6B6B), Icons.bluetooth_disabled,    'Error'),
      BleStatus.idle       => (const Color(0xFF4A5568), Icons.bluetooth_disabled,    'Not Connected'),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            _PulseDot(color: dotColor, animate: ble.status == BleStatus.scanning ||
                                                ble.status == BleStatus.connecting),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: TextStyle(
                      color: dotColor, fontWeight: FontWeight.w700, fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(ble.statusMessage,
                    style: const TextStyle(color: Color(0xFF8892B0), fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(icon, color: dotColor, size: 28),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, required this.animate});
  final Color color;
  final bool  animate;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>    _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 14, height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color,
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.5),
            blurRadius: 8, spreadRadius: 2,
          ),
        ],
      ),
    );

    if (!widget.animate) return dot;
    return ScaleTransition(scale: _scale, child: dot);
  }
}

// ── Connect / Disconnect button ───────────────────────────────

class _ConnectButton extends StatelessWidget {
  const _ConnectButton({required this.ble});
  final BleManager ble;

  @override
  Widget build(BuildContext context) {
    final busy = ble.status == BleStatus.scanning ||
                 ble.status == BleStatus.connecting;

    if (ble.isConnected) {
      return Center(
        child: TextButton.icon(
          onPressed: BleManager.instance.disconnect,
          icon: const Icon(Icons.bluetooth_disabled, size: 18, color: Color(0xFFFF6B6B)),
          label: const Text('Disconnect', style: TextStyle(color: Color(0xFFFF6B6B))),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: busy ? null : BleManager.instance.connect,
      icon: busy
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.black,
              ),
            )
          : const Icon(Icons.bluetooth_searching, size: 20),
      label: Text(
        busy ? 'Searching…' : 'Connect to ESP32',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Mode selection card ───────────────────────────────────────

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String    title;
  final String    description;
  final IconData  icon;
  final Color     color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                      style: const TextStyle(
                        color: Color(0xFFCCD6F6),
                        fontWeight: FontWeight.w700, fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(description,
                      style: const TextStyle(
                        color: Color(0xFF8892B0), fontSize: 13, height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: color, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
