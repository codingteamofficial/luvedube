// main.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';

RewardedAd? _rewardedAd;
final String _adUnitId = 'ca-app-pub-7211660777598396/4273277370';



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
          .toList());
}

class WriteASongPage extends StatefulWidget {
  const WriteASongPage({super.key});

  @override
  State<WriteASongPage> createState() => _WriteASongPageState();
}

class _WriteASongPageState extends State<WriteASongPage> {
  final List<SongSectionModel> _sections = [];
  final uuid = Uuid();
  bool _isArrangeMode = false;
  String typingPreview = '';

  
  final Map<String, bool> _sectionLocked = {};
  final Map<String, String?> _sectionPassword = {};
  final Map<String, List<TextEditingController>> _controllers = {}; // sectionId → list of line controllers
  final Map<String, List<bool>> _lineLocked = {}; // sectionId → line lock states
  final Map<String, String?> _linePassword = {};

  final Map<String, int> defaultLineCount = {
    'Verse': 4,
    'Hook': 2,
    'Chorus': 4,
    'Bridge': 2,
    'PreChorus': 2,
    'Outro': 2,
    'Instrumental': 1
  };

  @override
  void initState(){
    super.initState();
    _loadAd();
  }

  @override
  void dispose() {
    _controllers.forEach((k, list) {
      for (var c in list) {
        c.dispose();
      }
    });
    super.dispose();
  }

  void _loadAd() {
    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() { _rewardedAd = ad; });
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode) {
            print('Ad failed: $error');
          }
        },
      ),
    );
  }


  
  void _showAdThen(VoidCallback action) {
      // 1. Pehle user ka kaam hone do (Action first)
      action(); 

      // 2. Phir background mein ad dikhao agar ready hai
      if (_rewardedAd != null) {
        _rewardedAd!.show(
          onUserEarnedReward: (ad, reward) {            
          },
        );

        // Ad khatam hone par agli ad load karne ke liye
        _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            _loadAd(); 
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose();
            _loadAd();
          },
        );
        
        _rewardedAd = null; 
      } else {
       
        _loadAd();
      }
    }




  Future<Directory> _getDir() async {
    final d = await getApplicationDocumentsDirectory();
    final folder = Directory('${d.path}/LuveDubeSongVersions');
    if (!await folder.exists()) await folder.create(recursive: true);
    return folder;
  }

  Future<void> _saveVersion() async {
    final nameController = TextEditingController(
        text: 'Version_${DateTime.now().toIso8601String().replaceAll(":", "-")}');

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter version name'),
        content: TextField(controller: nameController),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    List<SongSectionModel> sections = [];
    for (var s in _sections) {
      final ctrs = _controllers[s.id] ?? [];
      final lines = ctrs.map((c) => c.text).toList();
      sections.add(SongSectionModel(
          id: s.id, type: s.type, lines: lines, password: _sectionPassword[s.id]));
    }

    final version = SongVersion(name: name, sections: sections);
    final file = File('${(await _getDir()).path}/$name.json');
    await file.writeAsString(jsonEncode(version.toJson()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Saved $name')));
  }

  Future<void> _saveIdea() async {
    final titleController = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Song Idea'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(hintText: 'Song Title'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'view'), child: const Text('View')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Save')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Cancel')),
        ],
      ),
    );

    final dir = await _getDir();
    final file = File('${dir.path}/SongIdeas.json');
    List<String> titles = [];
    if (await file.exists()) {
      titles = List<String>.from(jsonDecode(await file.readAsString()));
    }

    if (action == 'view') {
      await showDialog(
          // ignore: use_build_context_synchronously
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('Past Song Titles'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView(
                    shrinkWrap: true,
                    children: titles.map((t) => ListTile(title: Text(t))).toList(),
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
                ],
              ));
    } else if (action == 'save') {
      final title = titleController.text.trim();
      if (title.isEmpty) return;
      titles.add(title);
      await file.writeAsString(jsonEncode(titles));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Idea saved: $title')));
    }
  }

  Future<void> _showVersions({bool isDelete = false}) async {
    final dir = await _getDir();
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
    if (files.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No versions found')));
      return;
    }
    final names = files.map((f) => f.uri.pathSegments.last.replaceAll('.json', '')).toList();
    final selected = await showDialog<String>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(isDelete ? 'Delete Version' : 'Select Version'),
        children: names
            .map((n) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, n), child: Text(n)))
            .toList(),
      ),
    );

    if (selected == null) return;

    if (isDelete) {
      final file = File('${dir.path}/$selected.json');
      if (await file.exists()) {
        await file.delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Deleted $selected')));
      }
      return;
    }

    final file = File('${dir.path}/$selected.json');
    final jsonStr = await file.readAsString();
    final version = SongVersion.fromJson(jsonDecode(jsonStr));
    _loadVersion(version);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Loaded ${version.name}')));
  }

  void _loadVersion(SongVersion version) {
    // Clear existing data
    _sections.clear();
    _controllers.forEach((k, list) {
      for (var c in list) {
        c.dispose();
      }
    });
    _controllers.clear();
    _sectionLocked.clear();
    _sectionPassword.clear();
    _lineLocked.clear();
    _linePassword.clear();

    // Load new version
    for (var s in version.sections) {
      _sections.add(SongSectionModel(
        id: s.id,
        type: s.type,
        lines: s.lines,
        password: s.password,
      ));

      _sectionLocked[s.id] = s.password != null;
      _sectionPassword[s.id] = s.password;

      // Initialize controllers and line locks
      _controllers[s.id] = [];
      _lineLocked[s.id] = List.generate(s.lines.length, (_) => false); // ✅ Fixed
      _linePassword[s.id] = null;

      for (var line in s.lines) {
        _controllers[s.id]!.add(TextEditingController(text: line));
      }
    }

    setState(() {}); // Rebuild UI to show loaded version
  }

  Future<void> _exportTxt() async {
    final fileNameController = TextEditingController(text: 'MySong.txt');
    final fileName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export as TXT'),
        content: TextField(controller: fileNameController),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, fileNameController.text.trim()),
            child: const Text('Export'),
          ),
        ],
      ),
    );
    if (fileName == null || fileName.isEmpty) return;

    // Content build karein
    final sb = StringBuffer();
    for (var s in _sections) {
      sb.writeln('=== ${s.type} ===');
      final rows = _controllers[s.id] ?? [];
      for (var row in rows) {
        sb.writeln(row.text);
      }
      sb.writeln();
    }

    // Temp directory mein save karein (share ke liye)
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(sb.toString());

    if (!mounted) return;

    // Share sheet open hogi — WhatsApp, Gmail, Drive, etc.
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/plain')],
        subject: fileName,
      ),
    );
  }
  
  void _addModule(String type) {
    final id = uuid.v4();
    final initialLines = List.generate(defaultLineCount[type] ?? 3, (_) => ''); // default empty lines

    // Create the SongSectionModel
    final model = SongSectionModel(id: id, type: type, lines: initialLines);
    _sections.add(model);

    // Initialize controllers and line locks
    _controllers[id] = [];
    _lineLocked[id] = List.generate(initialLines.length, (_) => false); // ✅ Corrected
    _linePassword[id] = null;

    for (var line in initialLines) {
      _controllers[id]!.add(TextEditingController(text: line));
    }

    // Section lock state
    _sectionLocked[id] = false;
    _sectionPassword[id] = null;

    setState(() {}); // Refresh UI immediately
  }

  void _removeSection(String id) {
    if (_sectionLocked[id] == true) return;
    final idx = _sections.indexWhere((s) => s.id == id);
    if (idx >= 0) {
      for (var c in _controllers[id]!) {
        c.dispose();
      }
      _controllers.remove(id);
      _sections.removeAt(idx);
      _sectionLocked.remove(id);
      _sectionPassword.remove(id);
      _lineLocked.remove(id);
      _linePassword.remove(id);
      setState(() {});
    }
  }

  Future<void> _toggleSectionLock(String id) async {
    final locked = _sectionLocked[id] ?? false;
    if (!locked) {
      final pw = await _askPassword('Lock Section');
      if (pw != null && pw.isNotEmpty) {
        _sectionLocked[id] = true;
        _sectionPassword[id] = pw;
        setState(() {});
      }
    } else {
      final pw = await _askPassword('Unlock Section');
      if (pw == _sectionPassword[id]) {
        _sectionLocked[id] = false;
        _sectionPassword[id] = null;
        setState(() {});
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Incorrect password')));
      }
    }
  }

  Future<String?> _askPassword(String title) async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('OK')),
        ],
      ),
    );
    return res;
  }

Future<void> _toggleLineLock(String sectionId, int lineIndex) async {
  // Check if the line exists
  if (_lineLocked[sectionId] == null || lineIndex >= _lineLocked[sectionId]!.length) return;

  final isLocked = _lineLocked[sectionId]![lineIndex];
  final lineKey = '$sectionId-$lineIndex'; // unique key for passwords
  final currentPassword = _linePassword[lineKey];

  if (!isLocked) {
    // Locking the line → ask for password
    final pw = await _askPassword('Lock Line');
    if (pw != null && pw.isNotEmpty) {
      _lineLocked[sectionId]![lineIndex] = true;
      _linePassword[lineKey] = pw;
      setState(() {});
    }
  } else {
    // Unlocking → ask for password
    final pw = await _askPassword('Unlock Line');
    if (pw == currentPassword) {
      _lineLocked[sectionId]![lineIndex] = false;
      _linePassword.remove(lineKey);
      setState(() {});
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Incorrect password')));
    }
  }
}



@override
Widget build(BuildContext context) {
  final moduleTypes = ['Verse', 'Hook', 'Chorus', 'Bridge', 'PreChorus', 'Outro', 'Instrumental'];

  Widget appBarModuleButton(String label, {IconData? icon, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE6E6F0)),
            boxShadow: [BoxShadow(color: const Color.fromRGBO(137, 0, 0, 0.02), blurRadius: 6)],
          ),
          child: Row(
            children: [
              if (icon != null) Icon(icon, size: 18, color: Colors.indigo),
              if (icon != null) const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget linePreviewSection() {
    if (typingPreview.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black,
      child: Text(
        typingPreview,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  return Scaffold(
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 12,
        title: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 12.0),
              child: Text(
                'Write A Song',
                style: TextStyle(color: Colors.indigo, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    appBarModuleButton(
                      'Save Idea',
                      icon: Icons.save,
                      onTap: () => _showAdThen(_saveIdea),
                    ),

                    ...moduleTypes.map((t) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: LongPressDraggable<String>(
                          data: t,
                          feedback: Material(
                            color: Colors.transparent,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey)),
                              child: Text(t, style: const TextStyle(color: Colors.indigo)),
                            ),
                          ),
                          child: appBarModuleButton(
                            t,
                            onTap: () => _showAdThen(() => _addModule(t)),
                          ),
                        ),
                      );
                    }),

                    appBarModuleButton(
                      _isArrangeMode ? 'Stop Arrange' : 'Arrange',
                      icon: Icons.swap_vert,
                      onTap: () {
                        setState(() => _isArrangeMode = !_isArrangeMode);
                      },
                    ),

                    appBarModuleButton(
                      'Save Version',
                      icon: Icons.save_alt,
                      onTap: () => _showAdThen(_saveVersion),
                    ),

                    appBarModuleButton(
                      'Show Versions',
                      icon: Icons.list,
                      onTap: () => _showAdThen(() => _showVersions()),
                    ),

                    appBarModuleButton(
                      'Delete Version',
                      icon: Icons.delete_forever,
                      onTap: () => _showAdThen(() => _showVersions(isDelete: true)),
                    ),

                    appBarModuleButton(
                      'Export',
                      icon: Icons.file_download,
                      onTap: () => _showAdThen(_exportTxt),
                    ),

                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    body: Column(
      children: [
        linePreviewSection(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                      color: Color.fromRGBO(214, 0, 0, 0.04),
                      blurRadius: 12,
                      offset: Offset(0, 6))
                ],
                border: Border.all(color: const Color(0xFFE9E9EF)),
              ),
              child: DragTarget<String>(
                // ignore: unnecessary_null_comparison
                onWillAcceptWithDetails: (data) => data != null,
                onAcceptWithDetails: (details) =>
                    _showAdThen(() => _addModule(details.data)), // ✅ AD added
                builder: (context, candidateData, rejectedData) {
                  return ReorderableListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onReorder: (oldIndex, newIndex) {
                      if (!_isArrangeMode) return;
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _sections.removeAt(oldIndex);
                        _sections.insert(newIndex, item);
                      });
                    },
                    children: _sections.map((s) {
                      return Card(
                        key: ValueKey(s.id),
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.type,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _sectionLocked[s.id] == true
                                          ? Icons.lock
                                          : Icons.lock_open,
                                    ),
                                    onPressed: () => _toggleSectionLock(s.id),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: _sectionLocked[s.id] == true
                                        ? null
                                        : () => _showAdThen(() => _removeSection(s.id)),
                                  ),
                                ],
                              ),

                              Column(
                                children: List.generate(
                                  _controllers[s.id]!.length,
                                  (lineIndex) {
                                    final locked =
                                        _lineLocked[s.id]?[lineIndex] ?? false;

                                    return Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller:
                                                _controllers[s.id]![lineIndex],
                                            enabled: !locked,
                                            onChanged: (val) =>
                                                setState(() => typingPreview = val),
                                            onEditingComplete: () =>
                                                setState(() => typingPreview = ''),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(locked
                                              ? Icons.lock
                                              : Icons.lock_open),
                                          onPressed: () =>
                                              _toggleLineLock(s.id, lineIndex),
                                        )
                                      ],
                                    );
                                  },
                                ),
                              ),

                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      _controllers[s.id]!
                                          .add(TextEditingController());
                                      _lineLocked[s.id]!.add(false);
                                      setState(() {});
                                    },
                                    child: const Text("Add Line"),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (_controllers[s.id]!.isNotEmpty) {
                                        final idx =
                                            _controllers[s.id]!.length - 1;
                                        if (_lineLocked[s.id]![idx]) return;
                                        _controllers[s.id]!
                                            .removeAt(idx)
                                            .dispose();
                                        _lineLocked[s.id]!.removeAt(idx);
                                        setState(() {});
                                      }
                                    },
                                    child: const Text("Remove Line"),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
}