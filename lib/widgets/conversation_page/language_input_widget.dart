import 'package:ai_yu/data/state_models/preferences_model.dart';
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:speech_to_text/speech_recognition_error.dart";
import "package:speech_to_text/speech_recognition_result.dart";
import "package:speech_to_text/speech_to_text.dart" as stt;

class LanguageInputWidget extends StatefulWidget {
  final String language;
  final Function stopSpeaking;
  final ValueChanged<String> callbackFunction;

  const LanguageInputWidget({
    Key? key,
    required this.language,
    required this.stopSpeaking,
    required this.callbackFunction,
  }) : super(key: key);

  @override
  State<LanguageInputWidget> createState() => LanguageInputWidgetState();
}

class LanguageInputWidgetState extends State<LanguageInputWidget> {
  bool isListening = false;

  stt.SpeechToText speechRecognition = stt.SpeechToText();
  late Future<bool> speechRecognitionInitialization;

  final TextEditingController _promptInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    speechRecognitionInitialization = speechRecognition.initialize(
      onError: (error) => _listeningErrorHandler(error),
    );
  }

  // Always check if mounted before setting state.
  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  void _toggleListening() {
    if (isListening) {
      stopListening();
    } else {
      startListening();
    }
  }

  void _toggleAutoConversationMode() {
    final preferences = Provider.of<PreferencesModel>(context, listen: false);
    preferences.toggleAutoConversationMode();
    // If user just turned on auto conversation mode,
    // start listening right away.
    if (preferences.isAutoConversationMode) {
      startListening();
    }
  }

  void startListening() async {
    bool isInitialized = await speechRecognitionInitialization;
    if (!isInitialized || !mounted || isListening) {
      return;
    }

    await widget.stopSpeaking();

    setState(() {
      isListening = true;
      _promptInputController.text = "Listening...";
    });

    speechRecognition.listen(
      onResult: (val) {
        setState(() {
          final capitalizedText = val.recognizedWords[0].toUpperCase() +
              val.recognizedWords.substring(1);
          _promptInputController.text = capitalizedText;
        });
        if (val.finalResult) {
          _listeningCompletedHandler(val);
        }
      },
      partialResults: true,
      cancelOnError: false, // Errors -> _listeningErrorHandler.
      localeId: widget.language,
    );
  }

  void _clearPrompt() async {
    setState(() {
      isListening = false;
      _promptInputController.text = "";
    });
  }

  void stopListening({clearPrompt = true}) async {
    speechRecognition.cancel();
    if (clearPrompt) {
      _clearPrompt();
      _disableAutoModeAndNotifyUser();
    }
  }

  void _disableAutoModeAndNotifyUser() {
    final preferences = Provider.of<PreferencesModel>(context, listen: false);
    if (preferences.isAutoConversationMode) {
      preferences.setAutoConversationMode(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: "Auto mode disabled. Hold "),
                WidgetSpan(
                    child: Icon(
                  Icons.mic_none,
                  size: 16.0,
                  color: Colors.white,
                )),
                TextSpan(text: " to re-enable."),
              ],
            ),
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  void _listeningCompletedHandler(SpeechRecognitionResult val) async {
    setState(() {
      isListening = false;
    });
    final isAutoConversationMode =
        Provider.of<PreferencesModel>(context, listen: false)
            .isAutoConversationMode;
    if (isAutoConversationMode && val.finalResult && val.isConfident()) {
      _sendPrompt();
    }
  }

  void _listeningErrorHandler(SpeechRecognitionError error) {
    if (["error_no_match", "error_speech_timeout"].contains(error.errorMsg)) {
      // Very normal. Happens for example when no speech was detected.
      stopListening();
    } else {
      // Not normal. Show error message in prompt box.
      setState(() {
        _promptInputController.text = error.errorMsg;
      });
    }
  }

  void _sendPrompt() {
    // If last character is not punctuation, add a period.
    RegExp exp = RegExp(r"[\.\?!\,;:。？]$");
    final prompt = exp.hasMatch(_promptInputController.text)
        ? _promptInputController.text
        : "${_promptInputController.text}.";
    widget.callbackFunction(prompt);
    _clearPrompt();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    bool inputEmpty = _promptInputController.text.isEmpty;

    return Localizations.override(
      context: context,
      locale: Locale(widget.language),
      child: Builder(
        builder: (context) {
          return Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.primaryColor,
                  width: 1.0,
                ),
                bottom: BorderSide(
                  color: theme.primaryColor,
                  width: 6.0,
                ),
              ),
            ),
            child: Row(
              children: [
                Consumer<PreferencesModel>(
                    builder: (context, preferences, child) {
                  return InkWell(
                    onTap: _toggleListening,
                    onLongPress: _toggleAutoConversationMode,
                    child: Ink(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          FutureBuilder<bool>(
                              future: speechRecognitionInitialization,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Icon(Icons.pending,
                                      color: theme.colorScheme.secondary);
                                } else if (snapshot.hasError ||
                                    snapshot.data == false) {
                                  return Icon(Icons.mic_off,
                                      color: theme.colorScheme.secondary);
                                } else {
                                  return Icon(
                                      isListening
                                          ? Icons.cancel
                                          : (preferences.isAutoConversationMode
                                              ? Icons.auto_mode
                                              : Icons.mic_none),
                                      color: theme.primaryColor);
                                }
                              }),
                          if (preferences.isAutoConversationMode) ...[
                            const SizedBox(height: 8.0),
                            Center(
                                child: Text(
                              "AUTO\nMODE",
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            )),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10.0),
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: TextField(
                      controller: _promptInputController,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (value) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: "Enter prompt here.",
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      style: ButtonStyle(
                        padding: MaterialStateProperty.all(
                          const EdgeInsets.all(20.0),
                        ),
                      ),
                      onPressed: inputEmpty ? null : _sendPrompt,
                      icon: Icon(Icons.send, color: theme.primaryColor),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
