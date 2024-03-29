import 'package:ai_yu/data/gpt_mode.dart';
import "package:ai_yu/utils/supported_languages_provider.dart";

String? decideMission({required GPTMode mode, String? language}) {
  switch (mode) {
    case GPTMode.conversationPracticeMode:
      final String languageName =
          SupportedLanguagesProvider.getDisplayName(language!);
      /* return """
The user is studying $languageName, and you are to help them improve their
language skills. For each prompt, return a JSON response with up to 3 keys:
'feedback', 'corrected', and 'response'. 'feedback' should be a list of brief
suggestions, in English, explaining any issues with their sentence, or how they
could have made it sound more natural. 'corrected' should contain a more natural
version of their sentence / question that would have been better. And 'response'
should be your normal response that you would have provided if you didn't get
these special instructions. If the sentence is already quite good, no need to
provide 'feedback' and 'corrected'. Try to limit your responses to fairly
concise answers. Output correct, parsable JSON.
"""; */
      return """
The user is studying $languageName, and you are to help them improve their
language skills. Return helpful, short, and fairly easy to understand answers.
""";
    case GPTMode.deeplinkActionMode:
      return null;
    default:
      throw UnimplementedError(
          "Currently, only question and conversation modes are implemented.");
  }
}
