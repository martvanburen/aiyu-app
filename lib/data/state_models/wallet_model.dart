import 'dart:convert';

import 'package:ai_yu/awsconfiguration.dart';
import 'package:ai_yu/data/state_models/aws_model.dart';
import 'package:ai_yu/utils/event_recorder.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import "package:flutter/material.dart";

class WalletModel extends ChangeNotifier {
  late final AWSModel? _aws;
  bool _disposed = false;

  late final Future<void> _initialization;
  Future<void> get initialization => _initialization;

  // Measured in 100ths of a cent.
  late int? _microcentBalance;

  int? get microcentBalance => _microcentBalance;
  double? get centBalance =>
      _microcentBalance != null ? _microcentBalance! / 100.0 : null;
  double? get dollarBalance =>
      _microcentBalance != null ? _microcentBalance! / 10000.0 : null;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  WalletModel(this._aws, WalletModel? previousWallet) {
    _microcentBalance = previousWallet?._microcentBalance;
    _initialization = _fetchWalletBalance();
  }

  // Since this model is a proxy provider, it will be recreated whenever the
  // AWSModel changes, so we need to protect against calling notifyListeners()
  // on a disposed object.
  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  Future<void> _fetchWalletBalance() async {
    if (_aws == null) return;

    _isLoading = true;
    notifyListeners();

    if (_aws!.isSignedIn == null) {
      // If log-in state pending, balance is unavailable.
      _microcentBalance = null;
    } else if (_aws!.isSignedIn == false) {
      // If not logged in, balance is 0.
      _microcentBalance = 0;
    } else {
      // Otherwise, fetch from API.
      try {
        final cognitoPlugin =
            Amplify.Auth.getPlugin(AmplifyAuthCognito.pluginKey);
        final result = await cognitoPlugin.fetchAuthSession();
        final identityId = result.userPoolTokensResult.value.idToken.raw;

        final response = await Amplify.API.get(
          "/wallet/get-balance",
          apiName: "aiyu-backend",
          headers: {
            "Authorization": identityId,
            "x-api-key": apikey,
          },
        ).response;

        final jsonResponse = json.decode(response.decodeBody());
        _microcentBalance = jsonResponse["balance_hundredthcent"];
      } catch (e) {
        safePrint("Wallet fetch failed: '$e'. ");
        EventRecorder.errorWalletFetch();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  void setBalance({required int microcents}) {
    _microcentBalance = microcents;
    notifyListeners();
  }

  int _calculateQueryCost() {
    return 2;
  }

  double calculateQueryCostInCents() {
    return _calculateQueryCost() / 100.0;
  }

  void refresh() {
    _fetchWalletBalance();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
