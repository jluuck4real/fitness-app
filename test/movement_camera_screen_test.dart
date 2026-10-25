import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/screens/workouts/workout_detail_screen.dart';

void main() {
  testWidgets(
    'opens camera from active series and returns to the same exercise',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(
        const MaterialApp(
          home: WorkoutSessionScreen(
            workoutName: 'Treino de pernas',
            duration: 20,
            calories: 100,
            exercises: [
              {
                'name': 'Agachamento livre',
                'sets': 3,
                'reps': '12',
                'rest': 30,
                'muscle': 'Pernas',
              },
            ],
          ),
        ),
      );
      final button = find.text('VER MINHA EXECUÇÃO');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Ver minha execução'), findsOneWidget);
      expect(find.textContaining('Android e iPhone'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Voltar à série'), 200);
      await tester.tap(find.text('Voltar à série'));
      await tester.pumpAndSettle();
      expect(find.text('Agachamento livre'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('CONCLUIR SÉRIE'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
