import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/analytics_service.dart';
import '../../services/daily_routine_scope.dart';
import '../../services/exercise_repository.dart';
import '../../services/onboarding_scope.dart';
import '../../services/onboarding_service.dart';
import '../../services/reminder_settings_scope.dart';
import '../../services/app_notifications.dart';
import '../../services/telemetry_scope.dart';
import '../../models/exercise.dart';
import '../../widgets/shared/primary_button.dart';
import '../../widgets/onboarding/onboarding_progress_dots.dart';
import '../coach_generation_screen.dart';
import 'premium_intro_screen.dart';
import 'steps/experience_step.dart';
import 'steps/goals_step.dart';
import 'steps/reminders_step.dart';
import 'steps/summary_step.dart';
import 'steps/welcome_step.dart';

/// First-run onboarding flow: welcome/name, goals, experience level,
/// reminder opt-in, then a summary before handing off to the main app.
/// `_finish` also pushes a one-time [PremiumIntroScreen] between the
/// summary and actually completing onboarding — see that class's doc
/// comment and `_finish`'s comments for why the ordering there is
/// deliberate, not incidental.
///
/// Reads and writes an [OnboardingProfile] via [OnboardingScope]
/// as the user steps through, saving partial progress at each step so
/// nothing is lost if the app is closed mid-flow. On the final step,
/// [OnboardingService.completeOnboarding] is called, which is what
/// makes the app skip onboarding on every future launch — see the
/// gating logic in `main.dart`.
///
/// Reminder choices made in [RemindersStep] are applied to the real
/// [ReminderSettingsService] (requesting OS notification permission
/// and scheduling on-device) only once, when the user finishes.
class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  static const int _stepCount = 5;

  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();

  int _currentStep = 0;
  OnboardingProfile _draft = const OnboardingProfile();
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    // Resume from whatever was saved previously (e.g. the app was
    // closed mid-onboarding), rather than always starting blank.
    final existing = OnboardingScope.of(context, listen: false).profile;
    _draft = existing;
    _nameController.text = existing.name ?? '';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool get _isLastStep => _currentStep == _stepCount - 1;

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _persistDraft() async {
    await OnboardingScope.of(
      context,
      listen: false,
    ).saveProfile(_draft);
  }

  void _handleNext() {
    if (_currentStep == 0) {
      final name = _nameController.text.trim();
      _draft = _draft.copyWith(name: name.isEmpty ? null : name);
    }
    unawaited(_persistDraft());

    if (_isLastStep) {
      _finish();
    } else {
      _goToStep(_currentStep + 1);
    }
  }

  void _handleBack() {
    if (_currentStep == 0) return;
    _goToStep(_currentStep - 1);
  }

  void _toggleGoal(OnboardingGoal goal) {
    final updated = {..._draft.goals};
    if (!updated.remove(goal)) updated.add(goal);
    setState(() => _draft = _draft.copyWith(goals: updated));
  }

  void _selectExperience(ExperienceLevel level) {
    setState(() => _draft = _draft.copyWith(experienceLevel: level));
  }

  void _toggleReminder(String key) {
    final updated = {..._draft.remindersOptedIn};
    if (!updated.remove(key)) updated.add(key);
    setState(() => _draft = _draft.copyWith(remindersOptedIn: updated));
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);

    final onboarding = OnboardingScope.of(context, listen: false);
    final reminders = ReminderSettingsScope.of(context);
    final telemetry = TelemetryScope.of(context);

    // Apply each chosen reminder to the real reminder system. This
    // requests OS permission on the first enable call; if the user
    // denies it, that reminder simply stays off — it doesn't block
    // finishing onboarding.
    var anyReminderEnabled = false;
    for (final kind in ReminderKind.values) {
      if (_draft.remindersOptedIn.contains(kind.name)) {
        final enabled = await reminders.enable(kind);
        anyReminderEnabled = anyReminderEnabled || enabled;
      }
    }

    // Shown *before* completeOnboarding, deliberately — that call is
    // what flips hasCompletedOnboarding, which is what makes
    // _AppEntryPoint swap away from this whole screen. Showing the
    // preview first, while still on the pre-completion side of that
    // flag, keeps this widget safely mounted underneath it the entire
    // time the preview is up, rather than racing a rebuild that could
    // tear this down while a push is in flight. See
    // PremiumIntroScreen's own doc comment for the fuller picture.
    if (mounted) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (context) => const PremiumIntroScreen()),
      );
    }
    if (!mounted) return;

    // Also shown before completeOnboarding, for the same reason as
    // PremiumIntroScreen above — and it does real work while it's up:
    // this is what generates and persists the very first routine,
    // using _draft directly rather than waiting for
    // completeOnboarding to save it first. By the time
    // hasCompletedOnboarding flips below and _AppEntryPoint swaps to
    // the main app, today's routine already exists — the Routine tab
    // has nothing left to generate on its own first load, only
    // something to display.
    final dailyRoutine = DailyRoutineScope.of(context);
    await Navigator.of(context).push<List<Exercise>>(
      MaterialPageRoute(
        builder: (context) => CoachGenerationScreen(
          imageAsset: 'assets/images/coach/designing_routine.png',
          generate: () async {
            final catalog = await const ExerciseRepository().loadExercises();
            return dailyRoutine.ensureTodayRoutine(
              catalog: catalog,
              goals: _draft.goals,
              experienceLevel: _draft.experienceLevel,
            );
          },
        ),
      ),
    );
    if (!mounted) return;

    await onboarding.completeOnboarding(_draft);

    // Deliberately logs only the *shape* of the profile — how many
    // goals, which experience level, whether any reminder stuck. The
    // name the user entered is never sent; see AnalyticsEvent's doc
    // comment.
    telemetry.logEvent(
      AnalyticsEvent.onboardingCompleted(
        goalCount: _draft.goals.length,
        // Nullable on the profile — the experience step is skippable,
        // so 'unspecified' is a real outcome worth being able to see
        // in the data, not an error case to drop.
        experienceLevel: _draft.experienceLevel?.name ?? 'unspecified',
        anyReminderEnabled: anyReminderEnabled,
      ),
    );

    // No manual navigation needed: main.dart watches
    // `hasCompletedOnboarding` via OnboardingScope and swaps to the
    // main app automatically once this flips to true.
    if (mounted) setState(() => _finishing = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            OnboardingProgressDots(
              stepCount: _stepCount,
              currentStep: _currentStep,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentStep = index),
                children: [
                  Center(
                    child: SingleChildScrollView(
                      child: WelcomeStep(
                        controller: _nameController,
                        onSubmitted: _handleNext,
                      ),
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      child: GoalsStep(
                        selectedGoals: _draft.goals,
                        onToggle: _toggleGoal,
                      ),
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      child: ExperienceStep(
                        selectedLevel: _draft.experienceLevel,
                        onSelect: _selectExperience,
                      ),
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      child: RemindersStep(
                        selectedKeys: _draft.remindersOptedIn,
                        onToggle: _toggleReminder,
                      ),
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      child: SummaryStep(profile: _draft),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: _finishing ? null : _handleBack,
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  if (!_isLastStep && _currentStep > 0)
                    TextButton(
                      onPressed: _finishing ? null : _handleNext,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: PrimaryButton(
                label: _isLastStep ? 'Get started' : 'Continue',
                icon: _isLastStep ? Icons.check : null,
                onPressed: _finishing ? () {} : _handleNext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
