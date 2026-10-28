import 'package:flutter/foundation.dart';
import '../models/demo_account.dart';

class AuthController {
  final ValueNotifier<DemoAccount?> currentAccount =
      ValueNotifier<DemoAccount?>(null);

  bool signIn(String email, String password) {
    final account = DemoAccount.authenticate(email, password);

    if (account == null) return false;

    currentAccount.value = account;
    return true;
  }

  void signOut() {
    currentAccount.value = null;
  }

  void dispose() {
    currentAccount.dispose();
  }
}