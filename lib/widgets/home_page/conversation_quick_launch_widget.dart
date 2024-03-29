import 'package:ai_yu/data/state_models/preferences_model.dart';
import "package:ai_yu/utils/event_recorder.dart";
import "package:ai_yu/utils/supported_languages_provider.dart";
import "package:flutter/material.dart";
import "package:ai_yu/pages/conversation_page.dart";
import "package:provider/provider.dart";

class ConversationQuickLaunchWidget extends StatelessWidget {
  const ConversationQuickLaunchWidget({super.key});

  void _startConversation(
      BuildContext context, String language, bool isAutomaticMode) {
    EventRecorder.conversationStart(language,
        automaticMode: isAutomaticMode, quickLaunch: true);
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => LanguagePracticePage(language: language)));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PreferencesModel>(
      builder: (context, preferences, child) {
        if (preferences.recentLanguages.isEmpty) {
          // If no recent languages, don't display this widget.
          return const SizedBox();
        } else {
          return Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Expanded(
                    child: Text(
                  "Recent:",
                  textAlign: TextAlign.left,
                  style: TextStyle(color: Colors.grey),
                )),
                ...preferences.recentLanguages
                    .take(2)
                    .map((language) => Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: SizedBox(
                              child: FilledButton(
                            onPressed: () => _startConversation(context,
                                language, preferences.isAutoConversationMode),
                            child: Text(
                                SupportedLanguagesProvider.getDisplayName(
                                    language)),
                          )),
                        ))
                    .toList(),
              ],
            ),
          );
        }
      },
    );
  }
}
