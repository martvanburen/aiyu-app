import "package:ai_yu/data_structures/global_state/preferences_model.dart";
import "package:ai_yu/utils/supported_languages_provider.dart";
import "package:flutter/material.dart";
import "package:ai_yu/data_structures/gpt_mode.dart";
import "package:ai_yu/pages/conversation_page.dart";
import "package:provider/provider.dart";

class ConversationLaunchDialogWidget extends StatefulWidget {
  const ConversationLaunchDialogWidget({super.key});

  @override
  State<ConversationLaunchDialogWidget> createState() =>
      ConversationLaunchDialogWidgetState();
}

class ConversationLaunchDialogWidgetState
    extends State<ConversationLaunchDialogWidget> {
  String _selectedLanguage = SupportedLanguagesProvider.defaultLanguageCode;

  @override
  void initState() {
    super.initState();
  }

  Future startConversation(BuildContext context) {
    Provider.of<PreferencesModel>(context, listen: false)
        .addRecentLanguage(_selectedLanguage);
    return Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => LanguagePracticePage(
                mode: GPTMode.conversationMode, language: _selectedLanguage)));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PreferencesModel>(builder: (context, preferences, child) {
      return SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Divider(thickness: 2, color: Theme.of(context).dividerColor),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(children: [
                  const Text("Language:"),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedLanguage,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedLanguage = newValue!;
                        });
                      },
                      items: SupportedLanguagesProvider.getSupportedLanguages()
                          .map<DropdownMenuItem<String>>((String language) {
                        return DropdownMenuItem<String>(
                          value: language,
                          child: Text(SupportedLanguagesProvider.getDisplayName(
                              language)),
                        );
                      }).toList(),
                    ),
                  ),
                ]),
              ),
              const Divider(
                thickness: 2,
                color: Color.fromRGBO(0, 0, 0, 0.1),
                indent: 7,
                endIndent: 7,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        contentPadding: const EdgeInsets.all(0.0),
                        title: const Text(
                          "Conversation mode.",
                          style: TextStyle(fontSize: 14),
                        ),
                        value: preferences.isConversationMode,
                        onChanged: (newValue) {
                          preferences.setConversationMode(newValue!);
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text("Conversation mode."),
                              content: const Text("""
If enabled, the app will automatically:
- Start listening when it's your turn to speak.
- Submit if it's confident it understood you correctly."""),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text("OK"),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              Divider(thickness: 2, color: Theme.of(context).dividerColor),
            ],
          ));
    });
  }
}
