import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/presentation/widgets/profile_achievements_row.dart';
import 'package:mobile/features/rankings/data/models/achievement_model.dart';

AchievementModel _achievement(
  String name, {
  bool unlocked = true,
  String icon = 'music_note',
}) => AchievementModel(
  id: 'id-$name',
  code: name,
  name: name,
  description: 'desc',
  icon: icon,
  category: 'andean',
  requirementType: 'andean',
  requirementValue: 1,
  isUnlocked: unlocked,
);

Widget _host(List<AchievementModel> items, VoidCallback onViewAll) =>
    MaterialApp(
      home: Scaffold(
        body: ProfileAchievementsRow(achievements: items, onViewAll: onViewAll),
      ),
    );

void main() {
  testWidgets('renders nothing when there are no achievements', (tester) async {
    await tester.pumpWidget(_host(const [], () {}));
    expect(find.text('Logros recientes'), findsNothing);
  });

  testWidgets('lists recent achievements by name', (tester) async {
    await tester.pumpWidget(
      _host([
        _achievement('Primer Soplo Limpio'),
        _achievement('Maestro del Siku', unlocked: false),
      ], () {}),
    );
    expect(find.text('Logros recientes'), findsOneWidget);
    expect(find.text('Primer Soplo Limpio'), findsOneWidget);
    expect(find.text('Maestro del Siku'), findsOneWidget);
  });

  testWidgets('maps known icon names and falls back for unknown ones', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([
        _achievement('Known', icon: 'timer'),
        _achievement('Unknown', icon: 'no_such_icon'),
      ], () {}),
    );
    expect(find.byIcon(Icons.timer), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events), findsOneWidget);
  });

  testWidgets('"Ver todos" triggers onViewAll', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host([_achievement('A')], () => taps++));
    await tester.tap(find.text('Ver todos →'));
    expect(taps, 1);
  });
}
