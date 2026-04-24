import 'package:flutter/material.dart';
import '../../bridge/agent/AriAgent.dart';

class ConnectionWarningBanner extends StatelessWidget {
  const ConnectionWarningBanner({
    super.key,
    this.warningText = 'Connection to the AI agent server is unstable.',
    this.backgroundColor,
  });

  final String warningText;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: AriAgent.connectionStream,
      initialData: AriAgent.isConnected,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? false;
        if (isConnected) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: backgroundColor ?? const Color(0xFFE53935),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                warningText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
