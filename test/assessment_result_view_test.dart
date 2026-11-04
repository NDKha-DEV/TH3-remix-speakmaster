import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speakmaster_flutter/models/assessment.dart';
import 'package:speakmaster_flutter/widgets/assessment_result_view.dart';

void main() {
  final assessment = Assessment.fromJson(
    jsonDecode(File('test/fixtures/assessment_think.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  Future<List<String>> pump(WidgetTester tester) async {
    final spoken = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AssessmentResultView(
            assessment: assessment,
            onSpeak: (t) async => spoken.add(t),
            catalog: const {
              'θ': PhonemeInfo(
                symbol: 'θ',
                arpabet: 'TH',
                type: 'consonant',
                examples: ['think'],
                vnDifficulty: 3,
                confusions: ['s'],
                minimalPairs: [
                  ['think', 'sink']
                ],
                tipVi: 'Đặt đầu lưỡi giữa hai hàm răng',
                tipEn: '',
                vnNote: '',
              ),
            },
          ),
        ),
      ),
    ));
    return spoken;
  }

  testWidgets('shows score, level, words, phoneme error and catalog tip',
      (tester) async {
    await pump(tester);

    expect(find.text('78'), findsOneWidget);
    expect(find.text('Tốt'), findsOneWidget);
    expect(find.text('Ngữ điệu'), findsOneWidget);
    expect(find.text('think 45'), findsOneWidget);
    // Từ sai đầu tiên được chọn sẵn, âm sai đầu tiên được giải thích.
    expect(find.text('/θ/→/s/'), findsOneWidget);
    expect(find.textContaining('/θ/ đọc thành /t/ hoặc /s/'), findsOneWidget);
    expect(
        find.textContaining('Đặt đầu lưỡi giữa hai hàm răng'), findsOneWidget);
    expect(find.textContaining('Cặp từ đối lập: think ↔ sink'), findsOneWidget);
    expect(find.textContaining('Kết quả dự phòng'), findsNothing);
  });

  testWidgets('selecting another word shows its deleted phoneme',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('things 70'));
    await tester.pump();
    expect(find.text('/z/ ✕'), findsOneWidget);
    expect(find.textContaining('Thiếu âm đuôi -s/-es'), findsOneWidget);
  });

  testWidgets('practice word chips speak the word', (tester) async {
    final spoken = await pump(tester);
    final chip = find.widgetWithText(ActionChip, 'three');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    expect(spoken, ['three']);
  });
}
