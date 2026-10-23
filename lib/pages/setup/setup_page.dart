import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../../core/path_manager.dart';
import '../../widgets/launcher/launcher_common.dart';
import 'setup_window_bar.dart';

class LauncherSetupPage extends StatefulWidget {
  const LauncherSetupPage({super.key, required this.onConfigured});

  final Future<void> Function() onConfigured;

  @override
  State<LauncherSetupPage> createState() => _LauncherSetupPageState();
}

class _LauncherSetupPageState extends State<LauncherSetupPage> {
  bool _selecting = false;
  String? _error;

  Future<void> _selectDirectory() async {
    if (_selecting) return;
    setState(() {
      _selecting = true;
      _error = null;
    });

    try {
      String? selectedPath;
      try {
        selectedPath = await FilePicker.getDirectoryPath(
          dialogTitle: '选择启动器根目录',
        );
      } on FormatException catch (error) {
        selectedPath = await _promptDirectoryPath(error.message);
      } on PlatformException catch (error) {
        selectedPath = await _promptDirectoryPath(error.message ?? error.code);
      }

      if (!mounted) return;
      if (selectedPath == null || selectedPath.trim().isEmpty) {
        setState(() {
          _error = '必须选择一个有效的启动器根目录才能继续。';
        });
        return;
      }

      await PathManager.instance.configure(selectedPath);
      if (!mounted) return;
      await widget.onConfigured();
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = '无法创建启动器目录：${error.message}');
    } on FileSystemException catch (error) {
      if (mounted) {
        setState(
          () => _error =
              '无法创建启动器目录：${error.message}\n'
              '请确认启动器程序目录可写，且所选磁盘有足够空间。',
        );
      }
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  Future<String?> _promptDirectoryPath(String pickerError) async {
    final controller = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('选择启动器根目录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('文件夹选择器无法打开（$pickerError）。请直接输入根目录的完整路径。'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: '例如 E:\\Games'),
              onSubmitted: (value) =>
                  Navigator.pop(dialogContext, value.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('使用此目录'),
          ),
        ],
      ),
    );
    controller.dispose();
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF101510) : const Color(0xFFF1F4ED),
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [Color(0xFF172016), Color(0xFF0C110C)]
                    : const [Color(0xFFEAF2DF), Color(0xFFF7F9F3)],
              ),
            ),
          ),
          Column(
            children: [
              const SetupWindowBar(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: _buildSetupCard(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDirectoryExample(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = dark ? Colors.white : const Color(0xFF26351F);
    final mutedColor = dark ? const Color(0xFFA8B6A3) : const Color(0xFF5A6657);
    final borderColor = dark
        ? const Color(0xFF34452D)
        : const Color(0xFFD8E0D2);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF202B1E) : const Color(0xFFF1F5EC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '例如选择 E:\\Games 后，将创建：',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'E:\\Games\\Baogan Craft Launcher\\BGCL\n'
            'E:\\Games\\Baogan Craft Launcher\\.minecraft',
            style: TextStyle(
              fontSize: 12,
              height: 1.7,
              color: mutedColor,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x22E81123),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x66E81123)),
      ),
      child: Text(
        _error!,
        style: const TextStyle(
          fontSize: 12.5,
          height: 1.5,
          color: Color(0xFFE58A7A),
        ),
      ),
    );
  }

  Widget _buildSetupCard(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = dark ? Colors.white : const Color(0xFF26351F);
    final mutedColor = dark ? const Color(0xFFA8B6A3) : const Color(0xFF5A6657);
    final cardColor = dark ? const Color(0xFF1B241A) : const Color(0xFFF8FAF6);
    final borderColor = dark
        ? const Color(0xFF34452D)
        : const Color(0xFFD8E0D2);

    return Container(
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 28),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: BlockLogo(size: 72, radius: 16)),
          const SizedBox(height: 18),
          Text(
            '选择启动器根目录',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '首次启动必须完成目录设置，'
            '配置完成前不会创建日志、数据库或缓存文件。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.7, color: mutedColor),
          ),
          const SizedBox(height: 24),
          _buildDirectoryExample(context),
          if (_error != null) ...[const SizedBox(height: 16), _buildErrorBox()],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _selecting ? null : _selectDirectory,
            icon: _selecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open_rounded),
            label: Text(_selecting ? '正在创建目录…' : '选择根目录'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '取消文件夹选择不会进入主界面，请重新选择。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: mutedColor),
          ),
        ],
      ),
    );
  }
}
