import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../transactions/transaction_providers.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  late DateTime _start;
  late DateTime _end;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month);
    _end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import / Export')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Import CSV'),
            subtitle: const Text(
              'รองรับ columns date,type,amount,category,wallet,note',
            ),
            onTap: _busy ? null : _import,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.date_range),
            title: const Text('วันที่เริ่มต้น'),
            subtitle: Text(inputDateText(_start)),
            onTap: () => _pick(true),
          ),
          ListTile(
            leading: const Icon(Icons.event_available),
            title: const Text('วันที่สิ้นสุด'),
            subtitle: Text(inputDateText(_end)),
            onTap: () => _pick(false),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            label: const Text('Export และ Share CSV'),
            onPressed: _busy ? null : _export,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Export และ Share Excel'),
            onPressed: _busy ? null : _exportExcel,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Export และ Share PDF'),
            onPressed: _busy ? null : _exportPdf,
          ),
        ],
      ),
    );
  }

  Future<void> _pick(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('th', 'TH'),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      await ref.read(dataExchangeViewModelProvider).exportCsv(_start, _end);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _busy = true);
    try {
      await ref.read(dataExchangeViewModelProvider).exportExcel(_start, _end);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _busy = true);
    try {
      await ref.read(dataExchangeViewModelProvider).exportPdf(_start, _end);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final result = await ref.read(dataExchangeViewModelProvider).importCsv();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Import สำเร็จ ${result.importedCount} รายการ, ข้าม ${result.skippedCount} รายการ',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
