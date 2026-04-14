import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ble_manager.dart';
import '../widgets/info_banner.dart';
import '../widgets/send_controls.dart';

class ConstantModeScreen extends StatefulWidget {
  const ConstantModeScreen({super.key});

  @override
  State<ConstantModeScreen> createState() => _ConstantModeScreenState();
}

class _ConstantModeScreenState extends State<ConstantModeScreen> {
  double _throttle = 0;
  final _textController = TextEditingController(text: '0');
  bool _commandSent = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _setThrottle(double value) {
    final v = value.clamp(0.0, 100.0);
    setState(() {
      _throttle = v;
      _textController.text = v.toStringAsFixed(0);
      _commandSent = false;
    });
  }

  void _onTextChanged(String raw) {
    final parsed = double.tryParse(raw);
    if (parsed != null) {
      setState(() {
        _throttle = parsed.clamp(0.0, 100.0);
        _commandSent = false;
      });
    }
  }

  // Command format: CONST:<throttle>
  // e.g. CONST:75.0
  String get _command => 'CONST:${_throttle.toStringAsFixed(1)}';

  Future<void> _sendCommand() async {
    final ble = BleManager.instance;

    if (!ble.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Not connected — go back and connect to the ESP32 first.',
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: const Color(0xFFFF6B6B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final ok = await ble.sendCommand(_command);
    if (!mounted) return;

    if (ok) {
      setState(() => _commandSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sent: $_command',
            style: const TextStyle(color: Colors.black),
          ),
          backgroundColor: const Color(0xFF64FFDA),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Send failed: ${ble.statusMessage}',
            style: const TextStyle(color: Colors.black),
          ),
          backgroundColor: const Color(0xFFFF6B6B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Constant Throttle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const InfoBanner(
              message:
                  'Set the desired throttle, then tap Send. '
                  'The motor will hold this speed after Bluetooth signal is lost.',
            ),
            const SizedBox(height: 16),

            // Connection status strip
            ListenableBuilder(
              listenable: BleManager.instance,
              builder: (context, _) => ConnectionStrip(
                isConnected: BleManager.instance.isConnected,
              ),
            ),
            const SizedBox(height: 24),

            // Large throttle readout
            Center(
              child: Column(
                children: [
                  Text(
                    '${_throttle.toStringAsFixed(0)}%',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 72, fontWeight: FontWeight.w800,
                      color: _throttleColor(_throttle),
                    ),
                  ),
                  Text(
                    'Throttle',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(letterSpacing: 1.5, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Slider
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _throttleColor(_throttle),
                        thumbColor:       _throttleColor(_throttle),
                        overlayColor:     _throttleColor(_throttle).withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _throttle, min: 0, max: 100, divisions: 100,
                        label: '${_throttle.toStringAsFixed(0)}%',
                        onChanged: _setThrottle,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: ['0%', '50%', '100%']
                          .map((l) => Text(l,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontSize: 12)))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Manual text entry
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enter Throttle %',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontSize: 13, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _textController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d{0,3}\.?\d{0,1}')),
                      ],
                      onChanged: _onTextChanged,
                      style: const TextStyle(
                        color: Color(0xFFCCD6F6),
                        fontSize: 18, fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        hintText: '0 – 100',
                        suffixText: '%',
                        suffixStyle: TextStyle(color: Color(0xFF8892B0), fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quick-access buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick Set',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontSize: 13, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    Row(children: [
                      _QuickButton(
                        label: '0%',  color: const Color(0xFF64FFDA),
                        isActive: _throttle == 0,   onTap: () => _setThrottle(0),
                      ),
                      const SizedBox(width: 12),
                      _QuickButton(
                        label: '50%', color: const Color(0xFF00B4D8),
                        isActive: _throttle == 50,  onTap: () => _setThrottle(50),
                      ),
                      const SizedBox(width: 12),
                      _QuickButton(
                        label: '100%', color: const Color(0xFFFF6B6B),
                        isActive: _throttle == 100, onTap: () => _setThrottle(100),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Command preview
            CommandPreview(command: _command),
            const SizedBox(height: 16),

            // Send button
            SendButton(sent: _commandSent, onPressed: _sendCommand),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Color _throttleColor(double v) {
    if (v <= 30) return const Color(0xFF64FFDA);
    if (v <= 70) return const Color(0xFF00B4D8);
    return const Color(0xFFFF6B6B);
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.label, required this.color,
    required this.isActive, required this.onTap,
  });
  final String label;
  final Color  color;
  final bool   isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.2) : const Color(0xFF1A2F4A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? color : const Color(0xFF233554),
              width: isActive ? 2 : 1,
            ),
          ),
          child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? color : const Color(0xFF8892B0),
              fontWeight: FontWeight.w700, fontSize: 16,
            )),
        ),
      ),
    );
  }
}
