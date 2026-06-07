import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:kifdamari/pages/setting_page.dart';
import 'package:kifdamari/snackbars/show_error_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kifdamari/pages/version_info_page.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF3B56C4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/icon.png',
                    width: 50,
                    height: 50,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '棋譜だまり',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'アプリメニュー',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text(
              'アプリについて',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('設定'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('使い方'),
              onTap: () async {
              Navigator.pop(context);
              final Uri url = Uri.parse('https://sites.google.com/view/kifdamari-manual');
              try {
                if (await canLaunchUrl(url)) {
                  await launchUrl(
                    url,
                  );
                } else {
                  if (context.mounted) {
                    ShowErrorSnackbar.show(context, "ページを開けませんでした");
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ShowErrorSnackbar.show(context, "ページを開けませんでした");
                }
              }
            }
          ),
          ListTile(
            leading: const Icon(Icons.info_outlined),
            title: const Text('バージョン情報'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VersionInfoPage(),
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text(
              'SNS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('公式𝕏（旧Twitter）'),
            onTap: () async {
              Navigator.pop(context);
              final Uri url = Uri.parse('https://x.com/kif_damari');
              try {
                if (await canLaunchUrl(url)) {
                  await launchUrl(
                    url, 
                    mode: LaunchMode.externalApplication,
                  );
                } else {
                  if (context.mounted) {
                    ShowErrorSnackbar.show(context, "リンクを開けませんでした");
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ShowErrorSnackbar.show(context, "エラーが発生しました");
                }
              }
            },
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text(
              '法的情報',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('プライバシーポリシー'),
            onTap: () async {
              Navigator.pop(context);
              final Uri url = Uri.parse('https://sites.google.com/view/kifdamari-privacy');
              try {
                if (await canLaunchUrl(url)) {
                  await launchUrl(
                    url,
                  );
                } else {
                  if (context.mounted) {
                    ShowErrorSnackbar.show(context, "ページを開けませんでした");
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ShowErrorSnackbar.show(context, "ページを開けませんでした");
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('利用規約'),
            onTap: () async {
              Navigator.pop(context);
              final Uri url = Uri.parse('https://sites.google.com/view/kifdamari-terms');              
              try {
                if (await canLaunchUrl(url)) {
                  await launchUrl(
                    url,
                  );
                } else {
                  if (context.mounted) {
                    ShowErrorSnackbar.show(context, "ページを開けませんでした");
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ShowErrorSnackbar.show(context, "ページを開けませんでした");
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('ライセンス'),
            onTap: () {
              Navigator.pop(context);
              showLicensePage(
                context: context,
                applicationName: '棋譜だまり',
                applicationVersion: '1.0.0',
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Image.asset(
                    'assets/images/appbar_icon.png',
                    width: 48,
                    height: 48,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
