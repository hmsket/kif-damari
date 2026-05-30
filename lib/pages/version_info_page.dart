import 'package:flutter/material.dart';

class VersionInfoPage extends StatelessWidget {
  const VersionInfoPage({super.key});

  static const List<Map<String, dynamic>> _changelog = [
    {
      'version': '1.0.0',
      'date': '2026/05/24',
      'title': '初版リリース',
      'contents': [
        '「棋譜だまり」をリリースしました！'
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('バージョン情報'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _changelog.length,
        itemBuilder: (context, index) {
          final item = _changelog[index];
          final List<String> contents = item['contents'] as List<String>;

          return Card(
            margin: const EdgeInsets.all(8.0),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ver ${item['version']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        item['date'] as String,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  
                  Text(
                    item['title'] as String,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  ...contents.map((content) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('・ ', style: TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                content,
                                style: const TextStyle(height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
