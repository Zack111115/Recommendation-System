import 'package:flutter/material.dart';

import '../models/demo_account.dart';

class AccountScreen extends StatelessWidget {
  final DemoAccount account;
  final VoidCallback onLogout;
  final VoidCallback onRefresh;

  const AccountScreen({
    super.key,
    required this.account,
    required this.onLogout,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Tài khoản của tôi',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Thông tin phiên đăng nhập hiện tại.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF292947), Color(0xFF6558E8)],
            ),
          ),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 42,
                backgroundColor: Colors.white24,
                child: Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 45,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                account.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 23,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                account.email,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'Customer ID: ${account.id}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _infoTile(
          icon: Icons.badge_outlined,
          title: 'Mã khách hàng',
          value: account.id,
        ),
        _infoTile(
          icon: Icons.mail_outline,
          title: 'Tài khoản đăng nhập demo',
          value: account.email,
        ),
        _infoTile(
          icon: Icons.account_tree_outlined,
          title: 'Nguồn dữ liệu',
          value: 'Neo4j · Customer',
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Làm mới dữ liệu cửa hàng'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(15),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _confirmLogout(context),
          icon: const Icon(Icons.logout),
          label: const Text('Đăng xuất'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6558E8),
            padding: const EdgeInsets.all(15),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Đây là tài khoản demo. Đăng xuất chỉ kết thúc phiên hiện tại; '
          'giỏ hàng và lịch sử đã lưu trên Neo4j vẫn được giữ theo mã khách hàng.',
          style: TextStyle(color: Colors.black54, height: 1.6),
        ),
      ],
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EAF2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6558E8)),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 5),
                SelectableText(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text(
          'Bạn sẽ trở về màn hình đăng nhập. '
          'Giỏ hàng, lịch sử xem và lịch sử mua đã lưu trên hệ thống '
          'sẽ được giữ lại cho lần đăng nhập tiếp theo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true) onLogout();
  }
}