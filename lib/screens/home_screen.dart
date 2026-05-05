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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListenableBuilder(
              listenable: BleManager.instance,
              builder: (context, _) => _ConnectionCard(ble: BleManager.instance),
            ),
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: BleManager.instance,
              builder: (context, _) => _ConnectButton(ble: BleManager.instance),
            ),
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
            ListenableBuilder(
              listenable: BleManager.instance,
              builder: (context, _) => _CalibrateButton(ble: BleManager.instance),
            ),
            const SizedBox(height: 16),
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
    );
    _scale = Tween(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.animate) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.animate == old.animate) return;
    if (widget.animate) {
      _ctrl.repeat(reverse: true);
    } else {
      _ctrl
        ..stop()
        ..value = 0;
    }
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

// ── Calibrate ESC button ──────────────────────────────────────

class _CalibrateButton extends StatefulWidget {
  const _CalibrateButton({required this.ble});
  final BleManager ble;

  @override
  State<_CalibrateButton> createState() => _CalibrateButtonState();
}

class _CalibrateButtonState extends State<_CalibrateButton> {
  bool _sent = false;

  Future<void> _calibrate() async {
    if (!widget.ble.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect to the ESP32 first')),
      );
      return;
    }

    // Confirm — calibration requires the ESC to be unpowered first
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Calibrate ESC'),
        content: const Text(
          'ESC calibration procedure:\n\n'
          '1. Disconnect power from the ESC (motor off).\n'
          '2. Tap Calibrate — the ESP32 will hold max throttle.\n'
          '3. Power the ESC back on.\n'
          '4. Wait for the ESC to beep (≈ 3 s), then it will\n'
          '   drop to min throttle automatically.\n'
          '5. ESC beeps again — calibration done.\n\n'
          'Only needed once, or after changing the pulse range.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Calibrate'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final success = await widget.ble.sendCommand('CAL');
    if (!mounted) return;

    if (success) {
      setState(() => _sent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calibration started — power the ESC on now'),
          duration: Duration(seconds: 5),
        ),
      );
      // Reset the "sent" indicator after calibration window (3 s + buffer)
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _sent = false);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send calibration command')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _calibrate,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFFFC107),
        side: BorderSide(
          color: _sent
              ? const Color(0xFFFFC107)
              : const Color(0xFFFFC107).withValues(alpha: 0.4),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      icon: Icon(
        _sent ? Icons.check_circle_outline : Icons.tune,
        size: 18,
      ),
      label: Text(
        _sent ? 'Calibrating… power ESC on now' : 'Calibrate ESC',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
