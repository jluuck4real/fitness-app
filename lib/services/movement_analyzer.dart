import 'dart:math' as math;

enum MovementKind {
  squat,
  curl,
  shoulder,
  abdominal,
  lateral,
  triceps,
  press,
  pull,
  pushUp,
  lunge,
  plank,
  mirror,
}

enum MovementPhase { waiting, initial, moving, target }

enum ExecutionIssue { asymmetry, alignment }

class RepEvaluation {
  const RepEvaluation({
    required this.correct,
    required this.issues,
    required this.minimumAngle,
    required this.maximumSideDifference,
    required this.samples,
  });
  final bool correct;
  final Set<ExecutionIssue> issues;
  final double minimumAngle;
  final double? maximumSideDifference;
  final int samples;
}

class ExecutionReport {
  const ExecutionReport({
    required this.totalRepetitions,
    required this.correctRepetitions,
    required this.incompleteMovements,
    required this.issueCounts,
    required this.hasBilateralData,
    required this.hasAlignmentData,
    required this.samples,
    required this.isIsometric,
  });
  final int totalRepetitions;
  final int correctRepetitions;
  final int incompleteMovements;
  final Map<ExecutionIssue, int> issueCounts;
  final bool hasBilateralData;
  final bool hasAlignmentData;
  final int samples;
  final bool isIsometric;
  int get repetitionsWithIdentifiedIssues =>
      totalRepetitions - correctRepetitions;
  int get accuracyPercent => totalRepetitions == 0
      ? 0
      : ((correctRepetitions / totalRepetitions) * 100).round();
  bool get hasEvidence => samples > 0;
}

/// Counting thresholds are preserved from IAFit/main.py. Quality criteria are
/// evaluated only from landmarks that were detected in the current frame.
class MovementRule {
  const MovementRule(
    this.kind,
    this.joint,
    this.start,
    this.target, {
    this.increasing = false,
    this.isIsometric = false,
    this.supportsBilateralCheck = true,
    this.supportsAlignmentCheck = false,
  });
  final MovementKind kind;
  final String joint;
  final double start;
  final double target;
  final bool increasing;
  final bool isIsometric;
  final bool supportsBilateralCheck;
  final bool supportsAlignmentCheck;
  bool initial(double angle) => increasing ? angle < start : angle > start;
  bool reached(double angle) => increasing ? angle > target : angle < target;

  static MovementRule forExercise(String name) {
    switch (name.toLowerCase().trim()) {
      case 'agachamento livre':
      case 'agachamento':
      case 'squat':
        return const MovementRule(
          MovementKind.squat,
          'Joelho',
          160,
          90,
          supportsAlignmentCheck: true,
        );
      case 'rosca direta':
      case 'rosca martelo':
      case 'rosca concentrada':
      case 'biceps':
        return const MovementRule(MovementKind.curl, 'Cotovelo', 160, 50);
      case 'desenvolvimento':
      case 'desenvolvimento de ombros':
      case 'shoulder':
        return const MovementRule(
          MovementKind.shoulder,
          'Ombro',
          160,
          80,
          supportsAlignmentCheck: true,
        );
      case 'abdominal':
      case 'abdominal dinâmico':
      case 'abdominal tradicional':
        return const MovementRule(MovementKind.abdominal, 'Quadril', 160, 100);
      case 'elevação lateral':
      case 'elevacao lateral':
      case 'lateral':
        return const MovementRule(
          MovementKind.lateral,
          'Ombro',
          40,
          90,
          increasing: true,
          supportsAlignmentCheck: true,
        );
      case 'tríceps pulley':
      case 'triceps pulley':
        return const MovementRule(
          MovementKind.triceps,
          'Cotovelo',
          70,
          155,
          increasing: true,
        );
      case 'supino reto':
        return const MovementRule(MovementKind.press, 'Cotovelo', 160, 70);
      case 'puxada frontal':
        return const MovementRule(MovementKind.pull, 'Cotovelo', 160, 65);
      case 'flexão de braço':
      case 'flexao de braco':
      case 'flexão':
      case 'flexao':
        return const MovementRule(
          MovementKind.pushUp,
          'Cotovelo',
          160,
          80,
          supportsAlignmentCheck: true,
        );
      case 'afundo':
      case 'lunge':
        return const MovementRule(
          MovementKind.lunge,
          'Joelho',
          160,
          95,
          supportsAlignmentCheck: true,
        );
      case 'prancha':
        return const MovementRule(
          MovementKind.plank,
          'Alinhamento corporal',
          0,
          0,
          isIsometric: true,
          supportsBilateralCheck: false,
          supportsAlignmentCheck: true,
        );
      default:
        return const MovementRule(MovementKind.mirror, 'Sem regra', 0, 0);
    }
  }
}

class MovementAnalyzer {
  MovementAnalyzer(String name) : rule = MovementRule.forExercise(name);
  final MovementRule rule;
  MovementKind get kind => rule.kind;
  int repetitions = 0;
  int incompleteMovements = 0;
  MovementPhase phase = MovementPhase.waiting;
  final List<RepEvaluation> evaluations = [];
  final Map<ExecutionIssue, int> _issueCounts = {};
  bool _armed = false, _attempted = false;
  int _stableFrames = 0, _movingFrames = 0;
  bool? _lastCandidate;
  int _observedSamples = 0, _totalObservedSamples = 0, _alignmentSamples = 0;
  bool _hasBilateralData = false, _alignmentOutsideSafeRange = false;
  double _minimumAngle = double.infinity, _maximumSideDifference = 0;
  bool get supportsCounting => kind != MovementKind.mirror && !rule.isIsometric;
  bool get supportsEvaluation => kind != MovementKind.mirror;
  int get correctRepetitions =>
      evaluations.where((value) => value.correct).length;

  String get phaseLabel => switch (phase) {
    MovementPhase.waiting => 'Aguardando posição inicial',
    MovementPhase.initial =>
      kind == MovementKind.shoulder ? 'Braço elevado' : 'Posição inicial',
    MovementPhase.moving => 'Em movimento',
    MovementPhase.target => switch (kind) {
      MovementKind.squat || MovementKind.lunge => 'Flexão do joelho',
      MovementKind.curl ||
      MovementKind.triceps ||
      MovementKind.press ||
      MovementKind.pull ||
      MovementKind.pushUp => 'Movimento do cotovelo',
      MovementKind.shoulder => 'Retorno do braço',
      MovementKind.abdominal => 'Flexão do quadril',
      MovementKind.lateral => 'Elevação do braço',
      _ => 'Em acompanhamento',
    },
  };

  void loseTracking() {
    _armed = false;
    _attempted = false;
    _stableFrames = 0;
    _movingFrames = 0;
    _lastCandidate = null;
    _resetRepEvidence();
    phase = MovementPhase.waiting;
  }

  String update(double angle, {double? oppositeAngle, double? alignmentAngle}) {
    if (!supportsEvaluation)
      return 'Este exercício ainda não possui regra de avaliação.';
    if (!angle.isFinite || angle < 0 || angle > 180) {
      loseTracking();
      return 'Ângulo inválido. Reposicione-se para retomar o acompanhamento.';
    }
    _observe(
      angle,
      oppositeAngle: oppositeAngle,
      alignmentAngle: alignmentAngle,
    );
    if (rule.isIsometric) {
      phase = MovementPhase.moving;
      return _plankFeedback(alignmentAngle ?? angle);
    }
    final initial = rule.initial(angle), target = rule.reached(angle);
    if (!initial && !target) {
      _stableFrames = 0;
      _lastCandidate = null;
      phase = _armed ? MovementPhase.moving : MovementPhase.waiting;
      if (_armed && (angle - rule.start).abs() > 20 && ++_movingFrames >= 3)
        _attempted = true;
      return _angleFeedback(angle);
    }
    _stableFrames = _lastCandidate == target ? _stableFrames + 1 : 1;
    _lastCandidate = target;
    if (_stableFrames >= 3) {
      if (initial) {
        final incomplete = _armed && _attempted;
        if (incomplete) incompleteMovements++;
        _armed = true;
        _attempted = false;
        _movingFrames = 0;
        _resetRepEvidence();
        _observe(
          angle,
          oppositeAngle: oppositeAngle,
          alignmentAngle: alignmentAngle,
        );
        phase = MovementPhase.initial;
        if (incomplete)
          return 'Movimento incompleto detectado: houve retorno sem alcançar o limiar de ${rule.target.round()}°. É uma estimativa 2D.';
      } else if (_armed) {
        repetitions++;
        _finishRepetition();
        _armed = false;
        _attempted = false;
        phase = MovementPhase.target;
      }
    }
    return _angleFeedback(angle);
  }

  ExecutionReport report() => ExecutionReport(
    totalRepetitions: repetitions,
    correctRepetitions: correctRepetitions,
    incompleteMovements: incompleteMovements,
    issueCounts: Map.unmodifiable(_issueCounts),
    hasBilateralData: _hasBilateralData,
    hasAlignmentData: _alignmentSamples > 0,
    samples: _totalObservedSamples,
    isIsometric: rule.isIsometric,
  );

  void _observe(double angle, {double? oppositeAngle, double? alignmentAngle}) {
    _observedSamples++;
    _totalObservedSamples++;
    _minimumAngle = math.min(_minimumAngle, angle);
    if (oppositeAngle != null && oppositeAngle.isFinite) {
      _hasBilateralData = true;
      _maximumSideDifference = math.max(
        _maximumSideDifference,
        (angle - oppositeAngle).abs(),
      );
    }
    if (alignmentAngle != null && alignmentAngle.isFinite) {
      _alignmentSamples++;
      if (alignmentAngle < 135) _alignmentOutsideSafeRange = true;
    }
  }

  void _finishRepetition() {
    final issues = <ExecutionIssue>{};
    if (rule.supportsBilateralCheck &&
        _hasBilateralData &&
        _maximumSideDifference > 25)
      issues.add(ExecutionIssue.asymmetry);
    if (rule.supportsAlignmentCheck && _alignmentOutsideSafeRange)
      issues.add(ExecutionIssue.alignment);
    for (final issue in issues) {
      _issueCounts.update(issue, (count) => count + 1, ifAbsent: () => 1);
    }
    evaluations.add(
      RepEvaluation(
        correct: issues.isEmpty,
        issues: issues,
        minimumAngle: _minimumAngle.isFinite ? _minimumAngle : 0,
        maximumSideDifference: _hasBilateralData
            ? _maximumSideDifference
            : null,
        samples: _observedSamples,
      ),
    );
  }

  void _resetRepEvidence() {
    _observedSamples = 0;
    _minimumAngle = double.infinity;
    _maximumSideDifference = 0;
    _alignmentOutsideSafeRange = false;
  }

  String _plankFeedback(double alignment) {
    if (!alignment.isFinite)
      return 'Alinhamento indisponível. Mantenha ombro, quadril e tornozelo visíveis de lado.';
    if (alignment < 135)
      return 'Alinhamento corporal fora da faixa observável nesta imagem. Reenquadre-se de lado e ajuste a linha entre ombro, quadril e tornozelo.';
    return 'Alinhamento corporal 2D acompanhado. Continue respirando e interrompa se houver desconforto.';
  }

  String _angleFeedback(double angle) => switch (kind) {
    MovementKind.squat || MovementKind.lunge when angle < 70 => 'Flexão abaixo de 70° estimada. Confira uma amplitude confortável com orientação profissional.',
    MovementKind.squat || MovementKind.lunge when angle > 170 =>
      'Joelho próximo da extensão, acima de 170°.',
    MovementKind.squat ||
    MovementKind.lunge => 'Flexão do joelho acompanhada. Mova-se com controle.',
    MovementKind.curl ||
    MovementKind.press ||
    MovementKind.pull ||
    MovementKind.pushUp when angle > 160 => 'Braço estendido, acima de 160°.',
    MovementKind.curl ||
    MovementKind.press ||
    MovementKind.pull ||
    MovementKind.pushUp when angle < rule.target =>
      'Amplitude alvo do cotovelo detectada.',
    MovementKind.curl ||
    MovementKind.press ||
    MovementKind.pull ||
    MovementKind.pushUp => 'Movimento do cotovelo em andamento.',
    MovementKind.triceps when angle > 155 => 'Extensão do cotovelo detectada.',
    MovementKind.triceps => 'Extensão do cotovelo em andamento.',
    MovementKind.shoulder when angle > 160 =>
      'Braço elevado acima da cabeça. Retorne com controle.',
    MovementKind.shoulder when angle < 80 =>
      'Braço em posição mais baixa, abaixo de 80°.',
    MovementKind.shoulder => 'Ângulo do ombro em acompanhamento.',
    MovementKind.abdominal when angle > 160 =>
      'Quadril próximo da extensão, acima de 160°.',
    MovementKind.abdominal when angle < 100 =>
      'Flexão do quadril abaixo de 100° detectada.',
    MovementKind.abdominal => 'Flexão do quadril em andamento.',
    MovementKind.lateral when angle < 40 =>
      'Braço próximo ao corpo, abaixo de 40°.',
    MovementKind.lateral when angle > 90 => 'Elevação acima de 90° estimada. Respeite a amplitude orientada para você.',
    MovementKind.lateral => 'Elevação do braço em andamento.',
    _ => 'Sem regra de análise para este exercício.',
  };

  static double angle(
    math.Point<double> a,
    math.Point<double> b,
    math.Point<double> c,
  ) {
    if ((a - b).magnitude < .001 || (c - b).magnitude < .001) return double.nan;
    final degrees =
        ((math.atan2(c.y - b.y, c.x - b.x) - math.atan2(a.y - b.y, a.x - b.x)) *
                180 /
                math.pi)
            .abs();
    return degrees > 180 ? 360 - degrees : degrees;
  }
}
