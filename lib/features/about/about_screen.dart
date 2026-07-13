import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// About / sources page. Lists the corpus sources, building trust by
/// showing guidance is attributable (docs/design.md §7.7).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _sources = <_Source>[
    _Source(
        name: 'World Health Organization', bn: 'বিশ্ব স্বাস্থ্য সংস্থা (WHO)'),
    _Source(
        name: 'Bangladesh Red Crescent Society',
        bn: 'বাংলাদেশ রেড ক্রিসেন্ট সোসাইটি (BDRCS)'),
    _Source(
        name: 'Ministry of Disaster Management',
        bn: 'দুর্যোগ ব্যবস্থাপনা মন্ত্রণালয় (MoDMR)'),
    _Source(
        name: 'Bangladesh Meteorological Dept',
        bn: 'আবহাওয়া অধিদপ্তর (BMD)'),
    _Source(name: 'CDC', bn: 'সিডিসি'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('তথ্যসূত্র')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Brand header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ShongjogTheme.calmTeal,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Text(
                  'সংযোগ',
                  style: TextStyle(
                    color: ShongjogTheme.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'অফলাইন জরুরি সহায়তা — বাংলায়',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'শঙ্গ্যোগ-এর সমস্ত নির্দেশিকা নিচের প্রতিষ্ঠিত উৎস থেকে সংগৃহীত ও যাচাইকৃত। '
            'অ্যাপ কখনো রোগ নির্ণয় করে না বা ওষুধ দেয় না — শুধু সাধারণ সহায়তা দেয়।',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: ShongjogTheme.inkSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ..._sources.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ShongjogTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ShongjogTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: ShongjogTheme.calmTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.verified_outlined,
                            color: ShongjogTheme.calmTeal, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(s.bn,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: ShongjogTheme.inkSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ShongjogTheme.alertRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: ShongjogTheme.alertRed.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.phone_in_talk, color: ShongjogTheme.alertRed),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'জরুরি হলে সর্বদা ৯৯৯ নম্বরে কল করুন বা নিকটস্থ হাসপাতালে যান।',
                    style: TextStyle(fontSize: 15, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Source {
  final String name;
  final String bn;
  const _Source({required this.name, required this.bn});
}