import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ble_manager.dart';
import '../widgets/info_banner.dart';
import '../widgets/send_controls.dart';

enum SweepType { step, linear, sinusoidal }

class SweepModeScreen extends StatefulWidget {
  const SweepModeScreen({super.key});

  @override
  State<SweepModeScreen> createState() => _SweepModeScreenState();
}

class _SweepModeScreenState extends State<SweepModeScreen> {
  final _minController    = TextEditingController(text: '0');
  final _maxController    = TextEditingController(text: '100');
  final _stepController   = TextEditingController(text: '10');
  final _periodController = TextEditingController(text: '5');

  SweepType _sweepType = SweepType.linear;
  bool      _commandSent = false;

  String? _minError;
  String? _maxError;
  String? _stepError;
  String? _periodError;

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _stepController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  // Command format:
  //   SWEEP:L:<min>:<max>:<period>         linear
  //   SWEEP:N:<min>:<max>:<period>         sinusoidal
  //   SWEEP:S:<min>:<max>:<period>:<step>  step
  String get _command {
    final typeCode = switch (_sweepType) {
      SweepType.linear     => 'L',
      SweepType.sinusoidal => 'N',
      SweepType.step       => 'S',
    };
    final base =
        'SWEEP:$typeCode:${_minController.text}:${_maxController.text}:${_periodController.text}';
    return _sweepType == SweepType.step ? '$base:${_stepController.text}' : base;
  }

  bool _validate() {
    final min    = double.tryParse(_minController.text);
    final max    = double.tryParse(_maxController.text);
    final step   = double.tryParse(_stepController.text);
    final period = double.tryParse(_periodController.text);

    setState(() {
      _minError = min == null
          ? 'Enter a valid number'
          : (min < 0 || min > 100) ? 'Must be 0–100' : null;

      _maxError = max == null
          ? 'Enter a valid number'
          : (max < 0 || max > 100)
              ? 'Must be 0–100'
              : (min != null && max <= min)
                  ? 'Max must be greater than min'
                  : null;

      _stepError = _sweepType == SweepType.step
          ? (step == null
              ? 'Enter a valid number'
              : step <= 0
                  ? 'Must be greater than 0'
                  : (min != null && max != null && step >= (max - min))
                      ? 'Step must be smaller than range'
                      : null)
          : null;

      _periodError = period == null
          ? 'Enter a valid number'
          : period <= 0
              ? 'Must be greater than 0'
              : null;
    });

    return _minError == null &&
        _maxError == null &&
        _stepError == null &&
        _periodError == null;
  }

  Future<void> _sendCommand() async {
    if (!_validate()) return;

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
          content: Text('Sent: $_command',
              style: const TextStyle(color: Colors.black)),
          backgroundColor: const Color(0xFF64FFDA),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Send failed: ${ble.statusMessage}',
              style: const TextStyle(color: Colors.black)),
          backgroundColor: const Color(0xFFFF6B6B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _markUnsent() => setState(() => _commandSent = false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sweep Mode'),
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
                  'Configure the sweep profile, then tap Send. '
                  'The ESP32 will execute the sweep autonomously once submerged.',
            ),
            const SizedBox(height: 16),

            // Connection status
            ListenableBuilder(
              listenable: BleManager.instance,
              builder: (context, _) => ConnectionStrip(
                isConnected: BleManager.instance.isConnected,
              ),
            ),
            const SizedBox(height: 24),

            // Throttle range
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Throttle Range',
                        style: theme.textTheme.titleLarge?.copyWith(fontSize: 15)),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _PercentField(
                            controller: _minController, label: 'Min Throttle',
                            errorText: _minError, onChanged: (_) => _markUnsent(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _PercentField(
                            controller: _maxController, label: 'Max Throttle',
                            errorText: _maxError, onChanged: (_) => _markUnsent(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sweep type
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sweep Profile',
                        style: theme.textTheme.titleLarge?.copyWith(fontSize: 15)),
                    const SizedBox(height: 16),
                    _SweepTypeSelector(
                      selected: _sweepType,
                      onChanged: (t) => setState(() {
                        _sweepType    = t;
                        _commandSent  = false;
                        _stepError    = null;
                      }),
                    ),
                    if (_sweepType == SweepType.step) ...[
                      const SizedBox(height: 20),
                      _StepSizeSection(
                        controller: _stepController,
                        errorText: _stepError,
                        onChanged: (_) => _markUnsent(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Period
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sweep Period',
                        style: theme.textTheme.titleLarge?.copyWith(fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('Time for one complete sweep cycle',
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _periodController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d{0,5}\.?\d{0,2}')),
                      ],
                      onChanged: (_) => _markUnsent(),
                      style: const TextStyle(
                        color: Color(0xFFCCD6F6),
                        fontSize: 16, fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. 5',
                        suffixText: 's',
                        suffixStyle:
                            const TextStyle(color: Color(0xFF8892B0)),
                        errorText: _periodError,
                        errorStyle: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

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
}

// ── Subwidgets ────────────────────────────────────────────────

class _PercentField extends StatelessWidget {
  const _PercentField({
    required this.controller, required this.label,
    this.errorText, this.onChanged,
  });
  final TextEditingController controller;
  final String  label;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}\.?\d{0,1}')),
      ],
      onChanged: onChanged,
      style: const TextStyle(
        color: Color(0xFFCCD6F6), fontSize: 16, fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        suffixText: '%',
        suffixStyle: const TextStyle(color: Color(0xFF8892B0)),
        errorText: errorText,
        errorStyle: const TextStyle(fontSize: 11),
      ),
    );
  }
}

class _SweepTypeSelector extends StatelessWidget {
  const _SweepTypeSelector({required this.selected, required this.onChanged});
  final SweepType selected;
  final ValueChanged<SweepType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: SweepType.values.map((type) {
        final sel = selected == type;
        return GestureDetector(
          onTap: () => onChanged(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: sel
                  ? const Color(0xFF00B4D8).withValues(alpha: 0.12)
                  : const Color(0xFF1A2F4A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel ? const Color(0xFF00B4D8) : const Color(0xFF233554),
                width: sel ? 2 : 1,
              ),
            ),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: sel ? const Color(0xFF00B4D8) : const Color(0xFF4A5568),
                    width: 2,
                  ),
                  color: sel ? const Color(0xFF00B4D8) : Colors.transparent,
                ),
                child: sel
                    ? const Icon(Icons.check, size: 12, color: Colors.black)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_typeLabel(type),
                      style: TextStyle(
                        color: sel ? const Color(0xFFCCD6F6) : const Color(0xFF8892B0),
                        fontWeight: FontWeight.w600, fontSize: 15,
                      )),
                    const SizedBox(height: 2),
                    Text(_typeDesc(type),
                      style: const TextStyle(color: Color(0xFF4A5568), fontSize: 12,
                          height: 1.3)),
                  ],
                ),
              ),
              Icon(_typeIcon(type),
                color: sel ? const Color(0xFF00B4D8) : const Color(0xFF4A5568),
                size: 22),
            ]),
          ),
        );
      }).toList(),
    );
  }

  String _typeLabel(SweepType t) => switch (t) {
    SweepType.step       => 'Step Function',
    SweepType.linear     => 'Linear',
    SweepType.sinusoidal => 'Sinusoidal',
  };

  String _typeDesc(SweepType t) => switch (t) {
    SweepType.step       => 'Discrete jumps between throttle levels',
    SweepType.linear     => 'Triangle wave — ramps min→max→min each period',
    SweepType.sinusoidal => 'Smooth raised-cosine oscillation each period',
  };

  IconData _typeIcon(SweepType t) => switch (t) {
    SweepType.step       => Icons.stacked_line_chart,
    SweepType.linear     => Icons.trending_up,
    SweepType.sinusoidal => Icons.water,
  };
}

class _StepSizeSection extends StatelessWidget {
  const _StepSizeSection({
    required this.controller, this.errorText, this.onChanged,
  });
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Color(0xFF233554)),
        const SizedBox(height: 12),
        Text('Step Size',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontSize: 13, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}\.?\d{0,1}')),
          ],
          onChanged: onChanged,
          style: const TextStyle(
            color: Color(0xFFCCD6F6), fontSize: 16, fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'e.g. 10',
            suffixText: '%',
            suffixStyle: const TextStyle(color: Color(0xFF8892B0)),
            helperText: 'Size of each throttle increment',
            helperStyle: const TextStyle(color: Color(0xFF4A5568), fontSize: 11),
            errorText: errorText,
            errorStyle: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
}
