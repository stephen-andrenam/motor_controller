// Shared widgets used by both mode screens.
import 'package:flutter/material.dart';

/// Small strip showing current BLE connection state.
class ConnectionStrip extends StatelessWidget {
  const ConnectionStrip({super.key, required this.isConnected});
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final color =
        isConnected ? const Color(0xFF64FFDA) : const Color(0xFFFF6B6B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            isConnected
                ? 'ESP32 connected — ready to send'
                : 'Not connected',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the raw command string that will be sent over BLE.
class CommandPreview extends StatelessWidget {
  const CommandPreview({super.key, required this.command});
  final String command;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF233554)),
      ),
      child: Row(
        children: [
          const Text(
            'CMD  ',
            style: TextStyle(
              color: Color(0xFF48CAE4),
              fontSize: 12,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              command,
              style: const TextStyle(
                color: Color(0xFFCCD6F6),
                fontSize: 14,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Send / Command-Sent toggle button.
class SendButton extends StatelessWidget {
  const SendButton({super.key, required this.sent, required this.onPressed});
  final bool         sent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            sent ? const Color(0xFF1A3A2A) : const Color(0xFF00B4D8),
        foregroundColor:
            sent ? const Color(0xFF64FFDA) : Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 18),
        side: sent
            ? const BorderSide(color: Color(0xFF64FFDA), width: 1.5)
            : BorderSide.none,
      ),
      icon: Icon(
        sent ? Icons.check_circle_outline : Icons.send,
        size: 22,
      ),
      label: Text(
        sent ? 'Command Sent' : 'Send Command',
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    );
  }
}
