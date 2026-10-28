class DemoAccount {
  final String id;
  final String email;
  final String name;

  const DemoAccount({
    required this.id,
    required this.email,
    required this.name,
  });

  // Tao 60 tai khoan demo, tu C001 den C060.
  static final List<DemoAccount> all = List.generate(60, (index) {
    final number = (index + 1).toString().padLeft(3, '0');

    return DemoAccount(
      id: 'C$number',
      email: 'customer$number@example.test',
      name: 'Khách hàng $number',
    );
  });

  // Trong che do demo: mat khau bang Customer ID.
  bool verifyPassword(String password) {
    return password.trim().toUpperCase() == id;
  }

  static DemoAccount? authenticate(String email, String password) {
    final normalizedEmail = email.trim().toLowerCase();

    for (final account in all) {
      if (account.email == normalizedEmail &&
          account.verifyPassword(password)) {
        return account;
      }
    }

    return null;
  }
}