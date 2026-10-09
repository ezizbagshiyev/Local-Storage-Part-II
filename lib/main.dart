import 'package:flutter/material.dart';

import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper();

  try {
    await helper.init();
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error\\n$stackTrace');
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not open local storage. '
                'Restart the app and check the logs.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(DirectoryApp(helper: helper));
}

class DirectoryApp extends StatelessWidget {
  const DirectoryApp({super.key, required this.helper});
  final DatabaseHelper helper;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fall Festival Roster',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Builder(
        builder: (context) => FoldersScreen(
          repository: CardRepository(helper),
          onOpenRoster: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RosterScreen(helper: helper)),
          ),
        ),
      ),
    );
  }
}

class RosterScreen extends StatefulWidget {
  const RosterScreen({super.key, required this.helper});
  final DatabaseHelper helper;

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final ageController = TextEditingController();

  List<Map<String, dynamic>> rows = [];
  int count = 0;
  int? selectedId;
  bool busy = false;
  String? errorMessage;
  String? feedback;

  bool get editing => selectedId != null;

  @override
  void initState() {
    super.initState();
    loadRows();
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    super.dispose();
  }

  Future<void> loadRows() async {
    if (busy) return;
    setState(() {
      busy = true;
      errorMessage = null;
    });

    try {
      final newRows = await widget.helper.queryAllRows();
      final newCount = await widget.helper.queryRowCount();

      if (!mounted) return;
      setState(() {
        rows = newRows;
        count = newCount;
        busy = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Read failed: $error\\n$stackTrace');
      if (!mounted) return;
      setState(() {
        busy = false;
        errorMessage = 'Could not load the roster. Use Refresh to retry.';
      });
    }
  }

  String? validateName(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Enter a name.';
    return null;
  }

  String? validateAge(String? value) {
    final raw = (value ?? '').trim();
    final age = int.tryParse(raw);
    if (raw.isEmpty) return 'Enter an age.';
    if (age == null) return 'Age must be a whole number.';
    if (age < 0 || age > 130) return 'Age must be from 0 through 130.';
    return null;
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;

    final name = nameController.text.trim();
    final age = int.parse(ageController.text.trim());

    setState(() {
      busy = true;
      errorMessage = null;
      feedback = null;
    });

    try {
      if (editing) {
        final affected = await widget.helper.update({
          DatabaseHelper.columnId: selectedId,
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });

        if (affected == 0) {
          feedback = 'The selected row no longer exists.';
          await loadRows();
          return;
        }

        if (!mounted) return;
        setState(() {
          selectedId = null;
          nameController.clear();
          ageController.clear();
          feedback = 'Updated 1 row.';
        });
      } else {
        final id = await widget.helper.insert({
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });

        if (!mounted) return;
        setState(() {
          nameController.clear();
          ageController.clear();
          feedback = 'Saved row ID $id.';
        });
      }

      try {
        final newRows = await widget.helper.queryAllRows();
        final newCount = await widget.helper.queryRowCount();
        if (!mounted) return;
        setState(() {
          rows = newRows;
          count = newCount;
        });
      } catch (error, stackTrace) {
        debugPrint('Refresh after write failed: $error\\n$stackTrace');
        if (!mounted) return;
        setState(() {
          errorMessage = 'Saved, but refresh failed. Press Refresh to retry.';
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Write failed: $error\\n$stackTrace');
      if (!mounted) return;
      setState(() {
        errorMessage = 'Save failed. Your input was kept. Check the logs.';
      });
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  void editRow(Map<String, dynamic> row) {
    if (busy) return;
    setState(() {
      selectedId = row[DatabaseHelper.columnId] as int;
      nameController.text = row[DatabaseHelper.columnName] as String;
      ageController.text = '${row[DatabaseHelper.columnAge]}';
      feedback = 'Editing ID $selectedId.';
      errorMessage = null;
    });
  }

  void cancelEdit() {
    if (busy) return;
    setState(() {
      selectedId = null;
      nameController.clear();
      ageController.clear();
      feedback = 'Edit cancelled.';
      errorMessage = null;
    });
  }

  Future<void> deleteRow(Map<String, dynamic> row) async {
    final id = row[DatabaseHelper.columnId] as int;
    final name = row[DatabaseHelper.columnName] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete guest?'),
        content: Text('Delete ID $id, $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      busy = true;
      errorMessage = null;
      feedback = null;
    });

    try {
      final affected = await widget.helper.delete(id);

      if (affected == 0) {
        feedback = 'The selected row no longer exists.';
      } else {
        if (!mounted) return;
        setState(() {
          if (selectedId == id) {
            selectedId = null;
            nameController.clear();
            ageController.clear();
          }
          feedback = 'Deleted 1 row.';
        });
      }

      final newRows = await widget.helper.queryAllRows();
      final newCount = await widget.helper.queryRowCount();

      if (!mounted) return;
      setState(() {
        rows = newRows;
        count = newCount;
      });
    } catch (error, stackTrace) {
      debugPrint('Delete failed: $error\\n$stackTrace');
      if (!mounted) return;
      setState(() => errorMessage = 'Delete failed. Check the logs.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fall Festival Roster')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadRows,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          editing
                              ? 'Edit guest ID $selectedId'
                              : 'Add festival guest',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameController,
                          enabled: !busy,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: validateName,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: ageController,
                          enabled: !busy,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Age',
                            hintText: '0-130',
                            border: OutlineInputBorder(),
                          ),
                          validator: validateAge,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: busy ? null : save,
                                child: Text(editing ? 'Save' : 'Add'),
                              ),
                            ),
                            if (editing) ...[
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: busy ? null : cancelEdit,
                                child: const Text('Cancel edit'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Record count: $count',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : loadRows,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              if (busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (feedback != null) ...[
                const SizedBox(height: 12),
                Text(feedback!),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              if (!busy && errorMessage == null && rows.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No festival guests yet.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ...rows.map(
                (row) => Card(
                  child: ListTile(
                    title: Text(
                      '${row[DatabaseHelper.columnName]} '
                      '(age ${row[DatabaseHelper.columnAge]})',
                    ),
                    subtitle: Text('ID: ${row[DatabaseHelper.columnId]}'),
                    leading: CircleAvatar(
                      child: Text('${row[DatabaseHelper.columnId]}'),
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: busy ? null : () => editRow(row),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: busy ? null : () => deleteRow(row),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= Part II screens =================

/// Shows the card's image_ref if usable, otherwise a stable suit-symbol
/// placeholder. Supports bundled assets ("assets/...") and http(s) URLs.
/// Any missing, malformed, or unavailable reference falls back safely.
class CardImage extends StatelessWidget {
  const CardImage({super.key, required this.card, this.size = 48});
  final CardItem card;
  final double size;

  Widget _placeholder(BuildContext context) {
    final isRed = card.suit == 'hearts' || card.suit == 'diamonds';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        card.symbol,
        style: TextStyle(
          fontSize: size * 0.6,
          color: isRed ? Colors.red.shade700 : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = card.imageRef?.trim();
    if (ref == null || ref.isEmpty) return _placeholder(context);

    Widget? image;
    if (ref.startsWith('assets/')) {
      image = Image.asset(
        ref,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _placeholder(c),
      );
    } else {
      final uri = Uri.tryParse(ref);
      if (uri != null &&
          uri.hasAuthority &&
          (uri.scheme == 'http' || uri.scheme == 'https')) {
        image = Image.network(
          ref,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (c, child, progress) =>
              progress == null ? child : _placeholder(c),
          errorBuilder: (c, e, s) => _placeholder(c),
        );
      }
    }
    // Malformed reference: keep it stored, just don't try to render it.
    if (image == null) return _placeholder(context);
    return ClipRRect(borderRadius: BorderRadius.circular(8), child: image);
  }
}

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({
    super.key,
    required this.repository,
    required this.onOpenRoster,
  });
  final CardRepository repository;

  /// Opens the Part I roster screen (kept available per the spec).
  final VoidCallback onOpenRoster;

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  final nameController = TextEditingController();
  List<Folder> folders = [];
  bool busy = false;
  String? errorMessage;
  String? feedback;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final result = await widget.repository.getFoldersWithCounts();
      if (!mounted) return;
      setState(() {
        folders = result;
        errorMessage = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Folder read failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => errorMessage = 'Could not load folders. Pull to retry.');
    }
  }

  Future<void> addFolder() async {
    if (busy) return;
    final name = nameController.text.trim();
    if (name.isEmpty) {
      setState(() => errorMessage = 'Enter a folder name.');
      return;
    }
    setState(() {
      busy = true;
      errorMessage = null;
      feedback = null;
    });
    try {
      final id = await widget.repository.insertFolder(name);
      if (!mounted) return;
      nameController.clear();
      setState(() => feedback = 'Created folder ID $id.');
    } catch (error, stackTrace) {
      debugPrint('Folder insert failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        busy = false;
        errorMessage =
            'Could not create folder (names must be unique). Input kept.';
      });
      return;
    }
    // Write succeeded; refresh separately so a read failure never re-saves.
    await load();
    if (mounted) setState(() => busy = false);
  }

  Future<void> deleteFolder(Folder folder) async {
    if (busy) return;
    final id = folder.id!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
          'Delete "${folder.name}" (ID $id)? Its ${folder.cardCount} '
          'card(s) will also be deleted (cascade).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      busy = true;
      errorMessage = null;
      feedback = null;
    });
    try {
      final affected = await widget.repository.deleteFolder(id);
      if (!mounted) return;
      setState(() {
        feedback = affected == 0
            ? 'That folder no longer exists.'
            : 'Deleted folder "${folder.name}".';
      });
    } catch (error, stackTrace) {
      debugPrint('Folder delete failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        busy = false;
        errorMessage = 'Delete failed. Check the logs.';
      });
      return;
    }
    await load();
    if (mounted) setState(() => busy = false);
  }

  Future<void> openFolder(Folder folder) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardsScreen(
          repository: widget.repository,
          folderId: folder.id!,
          folderName: folder.name,
        ),
      ),
    );
    if (mounted) load(); // counts may have changed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Folders'),
        actions: [
          IconButton(
            tooltip: 'Part I roster',
            icon: const Icon(Icons.people_outline),
            onPressed: widget.onOpenRoster,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: nameController,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: 'New folder name',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => addFolder(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: busy ? null : addFolder,
                    child: const Text('Add'),
                  ),
                ],
              ),
              if (busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (feedback != null) ...[
                const SizedBox(height: 12),
                Text(feedback!),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              if (folders.isEmpty && errorMessage == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No folders yet. Create one above.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ...folders.map(
                (f) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(f.name),
                    subtitle: Text('ID ${f.id} · ${f.cardCount} card(s)'),
                    onTap: busy ? null : () => openFolder(f),
                    trailing: IconButton(
                      tooltip: 'Delete folder',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: busy ? null : () => deleteFolder(f),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CardsScreen extends StatefulWidget {
  const CardsScreen({
    super.key,
    required this.repository,
    required this.folderId,
    required this.folderName,
  });
  final CardRepository repository;
  final int folderId;
  final String folderName;

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  List<CardItem> cards = [];
  bool busy = false;
  bool loaded = false;
  String? errorMessage;
  String? feedback;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      // Queried by folder ID, never by name or list position.
      final result = await widget.repository.getCards(widget.folderId);
      if (!mounted) return;
      setState(() {
        cards = result;
        loaded = true;
        errorMessage = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Card read failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        loaded = true;
        errorMessage = 'Could not load cards. Pull to retry.';
      });
    }
  }

  Future<void> openForm([CardItem? card]) async {
    final saved = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CardFormScreen(
          repository: widget.repository,
          folderId: widget.folderId,
          card: card,
        ),
      ),
    );
    if (!mounted) return;
    if (saved != null) setState(() => feedback = saved);
    await load();
  }

  Future<void> deleteCard(CardItem card) async {
    if (busy) return;
    final id = card.id!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete card?'),
        content: Text('Delete "${card.title}" (ID $id)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      busy = true;
      errorMessage = null;
      feedback = null;
    });
    try {
      final affected = await widget.repository.deleteCard(id);
      if (!mounted) return;
      setState(() {
        feedback = affected == 0
            ? 'That card no longer exists.'
            : 'Deleted card "${card.title}".';
      });
    } catch (error, stackTrace) {
      debugPrint('Card delete failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        busy = false;
        errorMessage = 'Delete failed. Check the logs.';
      });
      return;
    }
    await load();
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.folderName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : () => openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add card'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              Text(
                'Folder ID ${widget.folderId} · ${cards.length} card(s)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (feedback != null) ...[
                const SizedBox(height: 12),
                Text(feedback!),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              if (loaded && cards.isEmpty && errorMessage == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No cards in this folder yet.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ...cards.map(
                (c) => Card(
                  child: ListTile(
                    leading: CardImage(card: c),
                    title: Text(c.title),
                    subtitle: Text(
                      'ID ${c.id} · ${c.suit}'
                      '${c.notes.isEmpty ? '' : '\n${c.notes}'}',
                    ),
                    isThreeLine: c.notes.isNotEmpty,
                    onTap: busy ? null : () => openForm(c),
                    trailing: IconButton(
                      tooltip: 'Delete card',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: busy ? null : () => deleteCard(c),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One form for both Add (card == null) and Edit (card != null).
class CardFormScreen extends StatefulWidget {
  const CardFormScreen({
    super.key,
    required this.repository,
    required this.folderId,
    this.card,
  });
  final CardRepository repository;
  final int folderId;
  final CardItem? card;

  @override
  State<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends State<CardFormScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController notesController;
  late final TextEditingController imageController;

  List<Folder> folders = [];
  int? selectedFolderId;
  String? selectedSuit;
  bool busy = false;
  String? errorMessage;

  bool get editing => widget.card != null;

  @override
  void initState() {
    super.initState();
    final c = widget.card;
    titleController = TextEditingController(text: c?.title ?? '');
    notesController = TextEditingController(text: c?.notes ?? '');
    imageController = TextEditingController(text: c?.imageRef ?? '');
    selectedFolderId = c?.folderId ?? widget.folderId;
    selectedSuit = c?.suit;
    loadFolders();
  }

  @override
  void dispose() {
    titleController.dispose();
    notesController.dispose();
    imageController.dispose();
    super.dispose();
  }

  Future<void> loadFolders() async {
    try {
      final result = await widget.repository.getFoldersWithCounts();
      if (!mounted) return;
      setState(() => folders = result);
    } catch (error, stackTrace) {
      debugPrint('Folder list failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => errorMessage = 'Could not load folders.');
    }
  }

  Future<void> save() async {
    if (busy) return;
    if (!formKey.currentState!.validate()) return;

    final imageText = imageController.text.trim();
    final card = CardItem(
      id: widget.card?.id,
      title: titleController.text.trim(),
      suit: selectedSuit!,
      notes: notesController.text.trim(),
      imageRef: imageText.isEmpty ? null : imageText,
      folderId: selectedFolderId!,
    );

    setState(() {
      busy = true;
      errorMessage = null;
    });
    try {
      String message;
      if (editing) {
        final affected = await widget.repository.updateCard(card);
        message = affected == 0
            ? 'The card no longer exists; nothing was updated.'
            : 'Updated card ID ${card.id}.';
      } else {
        final id = await widget.repository.insertCard(card);
        message = 'Saved card ID $id.';
      }
      if (!mounted) return;
      Navigator.pop(context, message);
    } catch (error, stackTrace) {
      debugPrint('Card write failed: $error\n$stackTrace');
      if (!mounted) return;
      // Input is preserved (controllers untouched).
      setState(() {
        busy = false;
        errorMessage = 'Save failed. Your input was kept. Check the logs.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit card ID ${widget.card!.id}' : 'Add card'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: titleController,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Enter a title.' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSuit,
                    decoration: const InputDecoration(
                      labelText: 'Suit *',
                      border: OutlineInputBorder(),
                    ),
                    items: CardItem.suits
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text('${CardItem.suitSymbols[s]} $s'),
                          ),
                        )
                        .toList(),
                    onChanged: busy ? null : (v) => selectedSuit = v,
                    validator: (v) =>
                        CardItem.isValidSuit(v) ? null : 'Pick a suit.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    // Re-key so the value appears once folders have loaded.
                    key: ValueKey('folders-${folders.length}'),
                    initialValue: folders.any((f) => f.id == selectedFolderId)
                        ? selectedFolderId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Folder *',
                      border: OutlineInputBorder(),
                    ),
                    items: folders
                        .map(
                          (f) => DropdownMenuItem(
                            value: f.id,
                            child: Text(f.name),
                          ),
                        )
                        .toList(),
                    onChanged: busy ? null : (v) => selectedFolderId = v,
                    validator: (v) => v == null ? 'Pick a folder.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    enabled: !busy,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: imageController,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: 'Image reference (optional)',
                      hintText: 'assets/... or https://...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (busy) const LinearProgressIndicator(),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: busy ? null : save,
                          child: Text(editing ? 'Save changes' : 'Add card'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        // Cancel writes nothing.
                        onPressed: busy ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

