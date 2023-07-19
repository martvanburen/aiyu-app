import "dart:convert";

import 'package:ai_yu/data/gpt_message.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

import '../data/state_models/wallet_model.dart';

bool _isCJKLanguage(String text) {
  int firstChar = text.codeUnitAt(0);
  // Unicode range for CJK Unified Ideographs (Chinese, Japanese, Korean).
  if (firstChar >= 0x4E00 && firstChar <= 0x9FFF) {
    return true;
  }
  return false;
}

int _estimateGptTokens(String text) {
  if (_isCJKLanguage(text)) {
    // For CJK languages, assume each character is a token.
    return text.length;
  } else {
    var words = text.split(' ').length;
    var characters = text.length;
    return words + (characters / 2).round();
  }
}

List<Map<String, String>> _limitMessagesToTokenCount(
    List<Map<String, String>> messages, int tokenLimit) {
  List<Map<String, String>> limitedMessages = [];

  int tokenCount = 0;
  for (var message in messages.reversed) {
    int messageTokens = _estimateGptTokens(message["content"]!);

    if (tokenCount + messageTokens > tokenLimit) {
      break;
    }

    limitedMessages.add(message);
    tokenCount += messageTokens;
  }

  return limitedMessages.reversed.toList();
}

Future<GPTMessageContent> callGptAPI(
  String? mission,
  List<GPTMessage> conversation, {
  int numTokensToGenerate = 600,
  WalletModel? wallet,
  bool getFeedback = false,
}) async {
  // TODO(mart): Clean this up.
  if ((wallet?.microcentBalance ?? 0) < 100) {
    await wallet?.initialization;
    if ((wallet?.microcentBalance ?? 0) < 100) {
      return GPTMessageContent(
          "A minimum balance of 1 cent is required to send GPT requests.");
    }
  }

  // Convert the conversation into the format the API expects.
  List<Map<String, String>> messages =
      await Future.wait(conversation.map((message) async {
    final content = await message.content;

    return {
      "role": message.sender == GPTMessageSender.user ? "user" : "assistant",
      "content": content.body,
    };
  }));

  // Restrict messages to ~2K tokens.
  messages = _limitMessagesToTokenCount(messages, 2000);

  // Add mission statement as first message.
  if (mission != null) {
    messages.insert(0, {
      "role": "system",
      "content": mission,
    });
  }

  // Make API call.
  dynamic data;
  try {
    final response = await Amplify.API
        .post(
          getFeedback ? "/gpt/3.5-turbo/withFeedback" : "/gpt/3.5-turbo",
          body: HttpPayload.json({
            "messages": messages,
            "max_tokens": numTokensToGenerate,
          }),
          apiName: "restapi",
        )
        .response;
    data = json.decode(response.decodeBody());
  } on ApiException catch (e) {
    return GPTMessageContent(e.message);
  }

  // Try parsing result.
  if (data["status"] == 200) {
    if (data.containsKey("new_balance_microcents")) {
      wallet?.setBalance(microcents: data["new_balance_microcents"]);
    }

    return GPTMessageContent(
      data["content"] ?? "",
      sentenceFeedback: data["feedback"],
      sentenceCorrection: data["corrected"],
    );
  } else {
    return GPTMessageContent(data["error"] ??
        "Unknown error occured (${data["status"]}). Please try again later.");
  }
}

Future<String> translateToEnglishUsingGPT(String text) async {
  // Make API call.
  dynamic data;
  try {
    final response = await Amplify.API
        .post(
          "/gpt/3.5-turbo",
          body: HttpPayload.json({
            "messages": [
              {
                "role": "user",
                "content": """
Please translate the following text into English (if not already). Respond only with the result.
$text
""",
              },
            ],
            "max_tokens": 300,
          }),
          apiName: "restapi",
        )
        .response;
    data = json.decode(response.decodeBody());
  } on ApiException catch (e) {
    return e.message;
  }

  // Try parsing result.
  if (data["status"] == 200) {
    return (data["content"] ?? "").trim();
  } else {
    return data["error"] ??
        "Unknown error occured (${data["status"]}). Please try again later.";
  }
}
