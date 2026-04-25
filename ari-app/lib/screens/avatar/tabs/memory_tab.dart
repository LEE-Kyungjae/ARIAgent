import 'package:flutter/material.dart';
import '../memory/standard_memory_section.dart';

class MemoryTab extends StatefulWidget {
  const MemoryTab({super.key});

  @override
  State<MemoryTab> createState() => _MemoryTabState();
}

class _MemoryTabState extends State<MemoryTab> {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      color: const Color(0xFF6C63FF),
      backgroundColor: const Color(0xFF1F1F3D),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          StandardMemorySection(onRefresh: () => setState(() {})),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
