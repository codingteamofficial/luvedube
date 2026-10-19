import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import 'package:luvedube/services/ad_service.dart';
import 'package:luvedube/theme/app_theme.dart';
import 'package:luvedube/widgets/donate_sheet.dart';
import 'package:luvedube/widgets/tech_widgets.dart';

// ───────────────────────── Persistence models (JSON format unchanged) ─────────────────────────

class SongSectionModel {
  String id;
  String type;
  List<String> lines;
  String? password;

  SongSectionModel({
    required this.id,
    required this.type,
    required this.lines,
    this.password,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'lines': lines,
        'password': password,
      };

  static SongSectionModel fromJson(Map<String, dynamic> j) => SongSectionModel(
        id: j['id'],
        type: j['type'],
        lines: List<String>.from(j['lines']),
        password: j['password'],
      );
}

class SongVersion {
  String name;
  List<SongSectionModel> sections;
  SongVersion({required this.name, required this.sections});

  Map<String, dynamic> toJson() =>
      {'name': name, 'sections': sections.map((s) => s.toJson()).toList()};

  static SongVersion fromJson(Map<String, dynamic> j) => SongVersion(
        name: j['name'],
        sections: (j['sections'] as List)
            .map((e) => SongSectionModel.fromJson(e))
            .toList(),
      );
}

// ───────────────────────── Live editing state ─────────────────────────

class _Line {
  _Line([String text = '']) : c = TextEditingController(text: text);
  final TextEditingController c;
  bool locked = false;
  String? pw;
  void dispose() => c.dispose();
}

class _Section {
  _Section({
    required this.id,
    required this.type,
    required this.lines,
    this.password,
  });
  final String id;
  final String type;
  final List<_Line> lines;
  String? password;
  bool get locked => password != null;
}

// ───────────────────────── Screen ─────────────────────────

class WriteASongPage extends StatefulWidget {
  const WriteASongPage({super.key});

  @override
  State<WriteASongPage> createState() => _WriteASongPageState();
}

class _WriteASongPageState extends State<WriteASongPage> {
  static const _moduleTypes = [
    'Verse',
    'Hook',
    'Chorus',
    'Bridge',
    'PreChorus',
    'Outro',
    'Instrumental',
  ];
  static const _defaultLineCount = {
    'Verse': 4,
    'Hook': 2,
    'Chorus': 4,
    'Bridge': 2,
    'PreChorus': 2,
    'Outro': 2,
    'Instrumental': 1,
  };

  final List<_Section> _sections = [];
  final _uuid = const Uuid();
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<String> _preview = ValueNotifier('');
  bool _arrange = false;

  @override
  void initState() {
    super.initState();
    AdService.instance.load();
  }

  @override
  void dispose() {
    for (final s in _sections) {
      for (final l in s.lines) {
        l.dispose();
      }
    }
    _preview.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── helpers ──

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _withAd(Future<void> Function() action) =>
      AdService.instance.runThenAd(action);

  /// Dispose controllers AFTER the frame that stops using them.
  void _disposeLater(Iterable<_Line> lines) {
    final list = lines.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final l in list) {
        l.dispose();
      }
    });
  }

  String _safe(String s) {
    final cleaned = s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'MySong' : cleaned;
  }

  String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }

  String _stats() {
    var lines = 0, words = 0;
    for (final s in _sections) {
      for (final l in s.lines) {
        lines++;
        final t = l.c.text.trim();
        if (t.isNotEmpty) words += t.split(RegExp(r'\s+')).length;
      }
    }
    return '${_sections.length} SECTIONS · $lines LINES · $words WORDS';
  }

  Future<(String, String)?> _askRaw(
    String title, {
    String initial = '',
    String hint = '',
    bool obscure = false,
    String ok = 'OK',
    String? secondary,
  }) {
    return showDialog<(String, String)>(
      context: context,
      builder: (_) => _PromptDialog(
        title: title,
        initial: initial,
        hint: hint,
        obscure: obscure,
        okLabel: ok,
        secondaryLabel: secondary,
      ),
    );
  }

  Future<String?> _ask(String title,
      {String initial = '',
      String hint = '',
      bool obscure = false,
      String ok = 'OK'}) async {
    final r = await _askRaw(title,
        initial: initial, hint: hint, obscure: obscure, ok: ok);
    return r?.$2;
  }

  Future<bool> _confirm(String title, String msg, {String ok = 'Delete'}) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: Tech.dialogShape,
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
        ],
      ),
    );
    return r ?? false;
  }

  Future<Directory> _dir() async {
    final d = await getApplicationDocumentsDirectory();
    final folder = Directory('${d.path}/LuveDubeSongVersions');
    if (!await folder.exists()) await folder.create(recursive: true);
    return folder;
  }

  Future<void> _openDonate() async {
    final exit = await showDonateSheet(context);
    if (exit) SystemNavigator.pop();
  }

  // ── sections & lines ──

  void _addModule(String type) {
    final n = _defaultLineCount[type] ?? 3;
    setState(() => _sections.add(_Section(
          id: _uuid.v4(),
          type: type,
          lines: List.generate(n, (_) => _Line()),
        )));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _removeSection(_Section s) async {
    if (s.locked) return;
    final hasText = s.lines.any((l) => l.c.text.trim().isNotEmpty);
    if (hasText) {
      final ok = await _confirm(
          'Delete ${s.type}?', 'Everything written in this section will be lost.');
      if (!ok || !mounted) return;
    }
    setState(() => _sections.remove(s));
    _disposeLater(s.lines);
  }

  Future<void> _toggleSectionLock(_Section s) async {
    if (!s.locked) {
      final pw = await _ask('Lock section',
          hint: 'Set a password', obscure: true, ok: 'Lock');
      if (!mounted) return;
      if (pw != null && pw.isNotEmpty) setState(() => s.password = pw);
    } else {
      final pw = await _ask('Unlock section',
          hint: 'Password', obscure: true, ok: 'Unlock');
      if (!mounted || pw == null) return;
      if (pw == s.password) {
        setState(() => s.password = null);
      } else {
        _toast('Incorrect password');
      }
    }
  }

  Future<void> _toggleLineLock(_Line l) async {
    if (!l.locked) {
      final pw = await _ask('Lock line',
          hint: 'Set a password', obscure: true, ok: 'Lock');
      if (!mounted) return;
      if (pw != null && pw.isNotEmpty) {
        setState(() {
          l.locked = true;
          l.pw = pw;
        });
      }
    } else {
      final pw = await _ask('Unlock line',
          hint: 'Password', obscure: true, ok: 'Unlock');
      if (!mounted || pw == null) return;
      if (pw == l.pw) {
        setState(() {
          l.locked = false;
          l.pw = null;
        });
      } else {
        _toast('Incorrect password');
      }
    }
  }

  void _addLine(_Section s) => setState(() => s.lines.add(_Line()));

  void _removeLastLine(_Section s) {
    if (s.lines.isEmpty) return;
    final last = s.lines.last;
    if (last.locked) {
      _toast('Unlock the last line first');
      return;
    }
    setState(() => s.lines.removeLast());
    _disposeLater([last]);
  }

  // ── versions / ideas / export ──

  Future<void> _saveVersion() async {
    if (_sections.isEmpty) {
      _toast('Add a section first');
      return;
    }
    final stamp = DateTime.now()
        .toIso8601String()
        .substring(0, 16)
        .replaceAll(':', '-')
        .replaceAll('T', '_');
    final raw = await _ask('Save version',
        initial: 'Version_$stamp', hint: 'Version name', ok: 'Save');
    if (raw == null || raw.isEmpty) return;
    final name = _safe(raw);

    final version = SongVersion(
      name: name,
      sections: _sections
          .map((s) => SongSectionModel(
                id: s.id,
                type: s.type,
                lines: s.lines.map((l) => l.c.text).toList(),
                password: s.password,
              ))
          .toList(),
    );
    final file = File('${(await _dir()).path}/$name.json');
    await file.writeAsString(jsonEncode(version.toJson()));
    _toast('Saved “$name”');
  }

  List<({String name, DateTime modified})> _listVersions(Directory dir) {
    final out = <({String name, DateTime modified})>[];
    for (final f in dir.listSync().whereType<File>()) {
      final base = f.path.split(Platform.pathSeparator).last;
      if (!base.endsWith('.json') || base == 'SongIdeas.json') continue;
      out.add((
        name: base.substring(0, base.length - 5),
        modified: f.statSync().modified,
      ));
    }
    out.sort((a, b) => b.modified.compareTo(a.modified));
    return out;
  }

  Future<void> _showVersions() async {
    final dir = await _dir();
    final entries = _listVersions(dir);
    if (!mounted) return;
    if (entries.isEmpty) {
      _toast('No saved versions yet');
      return;
    }

    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => _SheetShell(
          tag: 'VERSION HISTORY',
          title: '${entries.length} saved',
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final e in List.of(entries))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_rounded, color: Tech.cyan),
                  title: Text(e.name),
                  subtitle: Text(_fmt(e.modified), style: Tech.mono(size: 10.5)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Tech.magenta),
                    onPressed: () async {
                      final ok = await _confirm('Delete version?',
                          '“${e.name}” will be removed permanently.');
                      if (!ok) return;
                      final f = File('${dir.path}/${e.name}.json');
                      if (await f.exists()) await f.delete();
                      setSheet(() => entries.remove(e));
                      if (entries.isEmpty && ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                  onTap: () => Navigator.pop(ctx, e.name),
                ),
            ],
          ),
        ),
      ),
    );

    if (picked == null || !mounted) return;
    try {
      final txt = await File('${dir.path}/$picked.json').readAsString();
      _loadVersion(SongVersion.fromJson(jsonDecode(txt)));
      _toast('Loaded “$picked”');
    } catch (_) {
      _toast('Could not open that version');
    }
  }

  void _loadVersion(SongVersion v) {
    final old = _sections.expand((s) => s.lines).toList();
    setState(() {
      _sections
        ..clear()
        ..addAll(v.sections.map((s) => _Section(
              id: s.id,
              type: s.type,
              password: s.password,
              lines: s.lines.map((t) => _Line(t)).toList(),
            )));
    });
    _disposeLater(old);
  }

  Future<List<String>> _readIdeas(File f) async {
    try {
      if (await f.exists()) {
        return List<String>.from(jsonDecode(await f.readAsString()));
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveIdea() async {
    final r = await _askRaw('Save song idea',
        hint: 'Song title', ok: 'Save', secondary: 'View');
    if (r == null) return;
    final file = File('${(await _dir()).path}/SongIdeas.json');
    final titles = await _readIdeas(file);

    if (r.$1 == 'secondary') {
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheet) => _SheetShell(
            tag: 'SONG IDEAS',
            title: titles.isEmpty ? 'Nothing here yet' : '${titles.length} ideas',
            child: ListView(
              shrinkWrap: true,
              children: [
                for (var i = 0; i < titles.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const Icon(Icons.lightbulb_outline, color: Tech.amber),
                    title: Text(titles[i]),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Tech.muted),
                      onPressed: () async {
                        titles.removeAt(i);
                        await file.writeAsString(jsonEncode(titles));
                        setSheet(() {});
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    if (r.$2.isEmpty) return;
    titles.add(r.$2);
    await file.writeAsString(jsonEncode(titles));
    _toast('Idea saved: ${r.$2}');
  }

  Future<void> _exportTxt() async {
    if (_sections.isEmpty) {
      _toast('Nothing to export yet');
      return;
    }
    final raw = await _ask('Export as TXT',
        initial: 'MySong.txt', hint: 'File name', ok: 'Export');
    if (raw == null || raw.isEmpty) return;
    var name = _safe(raw);
    if (!name.toLowerCase().endsWith('.txt')) name = '$name.txt';

    final sb = StringBuffer();
    for (final s in _sections) {
      sb.writeln('=== ${s.type} ===');
      for (final l in s.lines) {
        sb.writeln(l.c.text);
      }
      sb.writeln();
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(sb.toString());
    if (!mounted) return;

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/plain')],
        subject: name,
      ),
    );
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Back = ask for support first, then exit
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _openDonate();
      },
      child: Scaffold(
        body: TechBackground(
          child: SafeArea(
            child: Column(
              children: [
                _header(),
                const SizedBox(height: 12),
                _toolbar(),
                const SizedBox(height: 10),
                _moduleStrip(),
                _previewStrip(),
                Expanded(child: _canvas()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 8, 0),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: Tech.brand,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                    color: Tech.violet.withValues(alpha: .5), blurRadius: 16),
              ],
            ),
            child: const Icon(Icons.graphic_eq_rounded, color: Colors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GradientText(
                  'WRITE A SONG',
                  gradient: Tech.brand,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                ),
                ValueListenableBuilder<String>(
                  valueListenable: _preview,
                  builder: (_, __, ___) =>
                      Text(_stats(), style: Tech.mono(size: 10)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Support LuveDuve',
            icon: const Icon(Icons.favorite_rounded, color: Tech.magenta),
            onPressed: _openDonate,
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _ToolChip(
            icon: Icons.lightbulb_outline_rounded,
            label: 'Save Idea',
            color: Tech.amber,
            onTap: () => _withAd(_saveIdea),
          ),
          _ToolChip(
            icon: Icons.save_alt_rounded,
            label: 'Save Version',
            color: Tech.cyan,
            onTap: () => _withAd(_saveVersion),
          ),
          _ToolChip(
            icon: Icons.history_rounded,
            label: 'Versions',
            color: Tech.violet,
            onTap: () => _withAd(_showVersions),
          ),
          _ToolChip(
            icon: Icons.ios_share_rounded,
            label: 'Export',
            color: Tech.mint,
            onTap: () => _withAd(_exportTxt),
          ),
          _ToolChip(
            icon: Icons.swap_vert_rounded,
            label: _arrange ? 'Done' : 'Arrange',
            color: Tech.magenta,
            active: _arrange,
            onTap: () => setState(() => _arrange = !_arrange),
          ),
        ],
      ),
    );
  }

  Widget _moduleStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
          child: Text('MODULES  //  TAP TO ADD · HOLD & DRAG TO DROP',
              style: Tech.mono(size: 9.5, spacing: 1.1)),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final t in _moduleTypes)
                LongPressDraggable<String>(
                  data: t,
                  feedback: Material(
                    color: Colors.transparent,
                    child: _ToolChip(
                      icon: Icons.add_rounded,
                      label: t,
                      color: Tech.accentFor(t),
                      active: true,
                      onTap: () {},
                    ),
                  ),
                  child: _ToolChip(
                    icon: Icons.add_rounded,
                    label: t,
                    color: Tech.accentFor(t),
                    tinted: true,
                    onTap: () => _withAd(() async => _addModule(t)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _previewStrip() {
    return ValueListenableBuilder<String>(
      valueListenable: _preview,
      builder: (_, v, __) => AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: v.isEmpty
            ? const SizedBox(width: double.infinity)
            : Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Tech.cyan.withValues(alpha: .5)),
                  boxShadow: [
                    BoxShadow(
                        color: Tech.cyan.withValues(alpha: .15), blurRadius: 16),
                  ],
                ),
                child: Row(
                  children: [
                    Text('LIVE', style: Tech.mono(size: 10, color: Tech.cyan)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        v,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _canvas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (d) => _withAd(() async => _addModule(d.data)),
        builder: (context, candidate, _) {
          final hot = candidate.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: hot
                    ? Tech.cyan
                    : Colors.white.withValues(alpha: .06),
                width: hot ? 1.6 : 1,
              ),
              color: hot ? Tech.cyan.withValues(alpha: .06) : Colors.transparent,
            ),
            child: _sections.isEmpty
                ? _emptyState()
                : ReorderableListView.builder(
                    scrollController: _scroll,
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
                    itemCount: _sections.length,
                    proxyDecorator: (child, _, __) =>
                        Material(color: Colors.transparent, child: child),
                    onReorder: (oldIndex, newIndex) {
                      if (!_arrange) return;
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        _sections.insert(newIndex, _sections.removeAt(oldIndex));
                      });
                    },
                    itemBuilder: (_, i) => _sectionCard(i, _sections[i]),
                  ),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Tech.cyan.withValues(alpha: .5)),
              boxShadow: [
                BoxShadow(color: Tech.cyan.withValues(alpha: .2), blurRadius: 30),
              ],
            ),
            child:
                const Icon(Icons.edit_note_rounded, color: Tech.cyan, size: 38),
          ),
          const SizedBox(height: 18),
          const Text('Your canvas is empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('TAP A MODULE ABOVE TO BEGIN', style: Tech.mono(size: 10.5)),
        ],
      ),
    );
  }

  Widget _sectionCard(int index, _Section s) {
    final accent = Tech.accentFor(s.type);
    final n = _sections.take(index + 1).where((x) => x.type == s.type).length;
    final tag = '${s.type.toUpperCase()} ${n.toString().padLeft(2, '0')}';

    return Padding(
      key: ValueKey(s.id),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GlassCard(
        accent: accent,
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: accent, blurRadius: 8)],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(tag,
                      style: Tech.mono(
                          size: 13,
                          color: accent,
                          weight: FontWeight.w800,
                          spacing: 1.8)),
                ),
                if (_arrange)
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.drag_indicator_rounded,
                          color: Tech.magenta),
                    ),
                  )
                else ...[
                  IconButton(
                    tooltip: s.locked ? 'Unlock section' : 'Lock section',
                    icon: Icon(
                      s.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                      color: s.locked ? Tech.mint : Tech.muted,
                      size: 20,
                    ),
                    onPressed: () => _toggleSectionLock(s),
                  ),
                  IconButton(
                    tooltip: 'Delete section',
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: Tech.muted,
                    disabledColor: Colors.white12,
                    onPressed:
                        s.locked ? null : () => _withAd(() => _removeSection(s)),
                  ),
                ],
              ],
            ),
            if (_arrange)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(
                  s.lines
                          .map((l) => l.c.text.trim())
                          .firstWhere((t) => t.isNotEmpty, orElse: () => '')
                          .isEmpty
                      ? '${s.lines.length} empty lines'
                      : s.lines
                          .map((l) => l.c.text.trim())
                          .firstWhere((t) => t.isNotEmpty),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Tech.muted),
                ),
              )
            else ...[
              for (var i = 0; i < s.lines.length; i++) _lineRow(s, i),
              const SizedBox(height: 10),
              Row(
                children: [
                  _MiniButton(
                    icon: Icons.add_rounded,
                    label: 'Line',
                    color: accent,
                    onTap: s.locked ? null : () => _addLine(s),
                  ),
                  const SizedBox(width: 8),
                  _MiniButton(
                    icon: Icons.remove_rounded,
                    label: 'Line',
                    color: accent,
                    onTap: s.locked ? null : () => _removeLastLine(s),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('${s.lines.length} LINES',
                        style: Tech.mono(size: 9.5)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lineRow(_Section s, int i) {
    final l = s.lines[i];
    final readOnly = s.locked || l.locked;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text((i + 1).toString().padLeft(2, '0'),
                style: Tech.mono(size: 10.5)),
          ),
          Expanded(
            child: TextField(
              controller: l.c,
              enabled: !readOnly,
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 15.5),
              decoration: InputDecoration(hintText: 'Line ${i + 1}'),
              onChanged: (v) => _preview.value = v,
              onSubmitted: (_) => _preview.value = '',
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: l.locked ? 'Unlock line' : 'Lock line',
            icon: Icon(
              l.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: 18,
              color: l.locked ? Tech.mint : Tech.muted,
            ),
            onPressed: s.locked ? null : () => _toggleLineLock(l),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Small private widgets ─────────────────────────

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.active = false,
    this.tinted = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool active;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(13);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: r,
              color: active
                  ? color.withValues(alpha: .2)
                  : Colors.white.withValues(alpha: .04),
              border: Border.all(
                color: active
                    ? color
                    : tinted
                        ? color.withValues(alpha: .45)
                        : Colors.white.withValues(alpha: .1),
              ),
              boxShadow: active
                  ? [BoxShadow(color: color.withValues(alpha: .3), blurRadius: 12)]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: active || tinted ? color : Tech.text),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: active || tinted ? color : Tech.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(10);
    final c = onTap == null ? Colors.white24 : color;
    return InkWell(
      borderRadius: r,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: r,
          border: Border.all(color: c.withValues(alpha: .5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: c),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: c)),
          ],
        ),
      ),
    );
  }
}

/// Owns (and properly disposes) its own TextEditingController.
class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.obscure,
    required this.okLabel,
    this.secondaryLabel,
  });

  final String title, initial, hint, okLabel;
  final bool obscure;
  final String? secondaryLabel;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String get _value => widget.obscure ? _c.text : _c.text.trim();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: Tech.dialogShape,
      title: Text(widget.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      content: TextField(
        controller: _c,
        autofocus: true,
        obscureText: widget.obscure,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (_) => Navigator.pop(context, ('ok', _value)),
      ),
      actions: [
        if (widget.secondaryLabel != null)
          TextButton(
            onPressed: () => Navigator.pop(context, ('secondary', _value)),
            child: Text(widget.secondaryLabel!),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, ('ok', _value)),
          child: Text(widget.okLabel),
        ),
      ],
    );
  }
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.tag,
    required this.title,
    required this.child,
  });

  final String tag, title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        color: Tech.surface.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Tech.cyan.withValues(alpha: .25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(tag, style: Tech.mono(size: 10.5, color: Tech.cyan, spacing: 2)),
          const SizedBox(height: 2),
          Text(title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Flexible(child: child),
        ],
      ),
    );
  }
}
