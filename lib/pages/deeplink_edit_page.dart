import 'package:ai_yu/data/state_models/deeplinks_model.dart';
import "package:ai_yu/utils/event_recorder.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:provider/provider.dart";

class DeeplinkEditPage extends StatefulWidget {
  final DeeplinkConfig? deeplink;

  const DeeplinkEditPage({super.key, this.deeplink});

  @override
  State<DeeplinkEditPage> createState() => _DeeplinkEditPageState();
}

class _DeeplinkEditPageState extends State<DeeplinkEditPage> {
  late TextEditingController _pathController;
  late TextEditingController _nameController;
  late TextEditingController _promptController;

  bool _isEdited = false;

  @override
  void initState() {
    super.initState();

    _pathController = TextEditingController(
        text: widget.deeplink != null ? widget.deeplink!.path : "");
    _nameController = TextEditingController(
        text: widget.deeplink != null ? widget.deeplink!.name : "");
    _promptController = TextEditingController(
        text: widget.deeplink != null ? widget.deeplink!.prompt : "");

    _pathController.addListener(_setEditFlag);
    _nameController.addListener(_setEditFlag);
    _promptController.addListener(_setEditFlag);
  }

  void _setEditFlag() {
    setState(() {
      _isEdited = true;
    });
  }

  Future<bool> _confirmDiscardingChanges() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Discard Changes?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text("Discard"),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }

  void _saveAndExit() {
    final deeplinks = Provider.of<DeeplinksModel>(context, listen: false);

    String path = _pathController.text.trim();
    String name = _nameController.text.trim();
    String prompt = _promptController.text.trim();

    if (path.isEmpty || name.isEmpty || prompt.isEmpty) {
      _showToast("All fields must be filled.");
      return;
    }

    if (!RegExp(r"^[a-zA-Z0-9_-]+$").hasMatch(path)) {
      _showToast("Path may only contain special characters '-', and '_'.");
      return;
    }

    if (!prompt.contains("\$Q")) {
      _showToast("GPT prompt must contain the \$Q keyword.");
      return;
    }

    // If adding a new deeplink (widget.deeplink == null), or editing but we
    // changed the deeplink path (path != widget.deeplink!.path), make sure the
    // new path doesn't clash with any existing deeplink.
    if ((widget.deeplink == null || path != widget.deeplink!.path) &&
        deeplinks.pathExists(path)) {
      _showToast("A deeplink with this path already exists.");
      return;
    }

    DeeplinkConfig deeplink = DeeplinkConfig(
      path: path,
      name: name,
      prompt: prompt,
    );
    if (widget.deeplink != null) {
      int index = deeplinks.get.indexOf(widget.deeplink!);
      deeplinks.updateIndex(index, deeplink);
      EventRecorder.deeplinkEdit();
    } else {
      deeplinks.add(deeplink);
      EventRecorder.deeplinkAdd();
    }

    Navigator.of(context).pop();
  }

  void _copyAnkiHTML() {
    String path = _pathController.text.trim();
    String name = _nameController.text.trim();

    // Purple style.
    /* Clipboard.setData(ClipboardData(
      text: """
<a href="aiyu://$path?q={{Front}}" style="
    display: inline-block;
    color: white;
    background-color: #${Theme.of(context).primaryColor.value.toRadixString(16).substring(2)};
    padding: 10px 20px;
    margin-bottom: 20px;
    text-decoration: none;
    text-align: center;
    font-size: 16px;
    border: none;
    border-top-left-radius: 5px;
    border-bottom-left-radius: 5px;
    box-shadow: 2px 2px 5px rgba(0, 0, 0, 0.3);
    position: absolute;
    bottom: 0px;
    /* If using multiple buttons, subsequent buttons should use:
     * bottom: 60px;
     * bottom: 120px;
     * ...
     */
    right: 0px;
"><b style="padding-right: 8px">→</b> $name</a>
""",
    )); */

    // Black-and-white style.
    Clipboard.setData(ClipboardData(
      text: """
<a href="aiyu://$path?q={{Front}}" style="
    display: inline-block;
    color: black;
    background-color: white;
    padding: 10px 20px;
    margin-bottom: 20px;
    text-decoration: none;
    text-align: center;
    font-size: 16px;
    font-weight: bold;
    border: 1px solid black;
    border-top-left-radius: 5px;
    border-bottom-left-radius: 5px;
    position: absolute;
    bottom: 0px;
    /* If using multiple buttons, subsequent buttons should use:
     * bottom: 60px;
     * bottom: 120px;
     * ...
     */
    right: 0px;
"><span style="padding-right: 8px">→</span> $name</a>
""",
    ));

    _showToast("Copied. Replace '{{Front}}' with the desired field!");
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _isEdited ? _confirmDiscardingChanges : null,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Edit Deeplink"),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: "Name",
                    labelStyle:
                        TextStyle(color: Theme.of(context).primaryColor),
                    counterText: "",
                  ),
                  textCapitalization: TextCapitalization.words,
                  maxLength: 200,
                  maxLines: null,
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 10.0),
                TextField(
                  controller: _pathController,
                  decoration: InputDecoration(
                    labelText: "Deeplink URL",
                    labelStyle:
                        TextStyle(color: Theme.of(context).primaryColor),
                    prefixText: "aiyu://",
                  ),
                  onTap: () {
                    if (_pathController.text.isEmpty &&
                        _nameController.text.isNotEmpty) {
                      _pathController.text = _nameController.text
                          .toLowerCase()
                          .replaceAll(' ', '-');
                    }
                  },
                  onChanged: (value) {
                    _setEditFlag();
                    if (value.startsWith("aiyu://")) {
                      _pathController.value = _pathController.value.copyWith(
                        text: value.substring("aiyu://".length),
                      );
                    }
                  },
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 10.0),
                TextField(
                  controller: _promptController,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: "GPT Prompt",
                    labelStyle:
                        TextStyle(color: Theme.of(context).primaryColor),
                    hintText:
                        "Example: What are some Chinese words that are commonly confused with \$Q.",
                  ),
                ),
                const SizedBox(height: 5.0),
                Text(
                  "The keyword '\$Q' will be replaced with your flashcard's data.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 40.0),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    child: const Text("Save"),
                    onPressed: () => _saveAndExit(),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    child: const Text("Copy HTML for Anki"),
                    onPressed: () => _copyAnkiHTML(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pathController.dispose();
    _nameController.dispose();
    _promptController.dispose();

    super.dispose();
  }
}
