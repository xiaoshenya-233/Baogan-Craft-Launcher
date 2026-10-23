import 'dart:async';

import 'package:flutter/material.dart';

import '../services/translation/database_service.dart';

class LocalizedModTitle extends StatefulWidget {
  const LocalizedModTitle({super.key, required this.englishTitle, this.style});

  final String englishTitle;
  final TextStyle? style;

  @override
  State<LocalizedModTitle> createState() => _LocalizedModTitleState();
}

class _LocalizedModTitleState extends State<LocalizedModTitle> {
  late final ValueNotifier<String> _title;
  int _translationGeneration = 0;

  @override
  void initState() {
    super.initState();
    _title = ValueNotifier<String>(
      McmodTitleService.instance.cachedChineseTitle(widget.englishTitle) ??
          widget.englishTitle,
    );
    _startTranslation();
  }

  @override
  void didUpdateWidget(covariant LocalizedModTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.englishTitle != widget.englishTitle) {
      _title.value =
          McmodTitleService.instance.cachedChineseTitle(widget.englishTitle) ??
          widget.englishTitle;
      _startTranslation();
    }
  }

  void _startTranslation() {
    final generation = ++_translationGeneration;
    final englishTitle = widget.englishTitle;
    if (englishTitle.trim().isEmpty ||
        RegExp(r'[\u4e00-\u9fff]').hasMatch(englishTitle)) {
      return;
    }
    final cached = McmodTitleService.instance.cachedChineseTitle(englishTitle);
    if (cached != null) {
      if (cached != _title.value) _title.value = cached;
      return;
    }
    unawaited(
      McmodTitleService.instance.translateAndCache(englishTitle).then((value) {
        if (!mounted || generation != _translationGeneration) return;
        if (value != englishTitle && value != _title.value) {
          _title.value = value;
        }
      }),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: _title,
      builder: (context, title, child) => Text(title, style: widget.style),
    );
  }
}
