/// Picks one entry from [options] based on today's calendar date, so
/// the same item shows all day and a different one shows tomorrow —
/// used for [HomeHeroHeader]'s quote, [CoachMessageCard]'s message,
/// and [DailyInsightCard]'s insight.
///
/// Deliberately stateless: no persistence, no service, just a
/// function of "what day is it" — there's nothing here to preserve or
/// break as business logic, only presentation content that happens to
/// change daily. [options] must be non-empty.
T pickForToday<T>(List<T> options) {
  assert(options.isNotEmpty, 'pickForToday requires at least one option');
  final today = DateTime.now();
  final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays;
  return options[dayOfYear % options.length];
}
