import '../models/wellness_article.dart';

/// Bundled, offline content for the Wellness Library.
///
/// Every article ships inside the app itself — nothing here is
/// fetched over the network — so the library is fully readable
/// offline and loads instantly. This is a static, hand-authored list
/// rather than a service with a `load()` step, since the content
/// never changes at runtime; [WellnessLibraryScreen] reads
/// [WellnessLibraryContent.articles] directly.
///
/// Content guidelines followed throughout:
/// - Educational and habit-focused, never diagnostic or prescriptive.
///   Nothing here tells the reader they have a condition or promises
///   to treat one.
/// - No cosmetic outcome claims (no "erase wrinkles", "sculpt your
///   jawline", "reverse aging", etc.) — only plain descriptions of
///   common habits and why people find them useful.
/// - Encourages consulting a doctor, dentist, or other qualified
///   professional for anything persistent or painful, rather than
///   Claude — this app — offering guidance in their place.
abstract final class WellnessLibraryContent {
  static const List<WellnessArticle> articles = [
    // ---- Jaw relaxation -------------------------------------------------
    WellnessArticle(
      id: 'jaw_where_tension_hides',
      topic: WellnessTopic.jawRelaxation,
      title: 'Where Jaw Tension Hides',
      summary:
          'Many people clench without noticing, especially while '
          'focused or asleep. Here\'s how that tension tends to show up.',
      readMinutes: 3,
      tags: ['clenching', 'tmj', 'grinding', 'tension'],
      sections: [
        ArticleSection(
          heading: 'A habit you might not notice',
          body:
              'Jaw clenching often happens automatically during '
              'concentration, stress, or sleep, so it can go unnoticed for '
              'a long time. A common sign is waking up with a tired or '
              'tight feeling around the jaw or temples.',
        ),
        ArticleSection(
          heading: 'Common everyday triggers',
          body:
              'Screen time, stressful moments, and even chewing gum for '
              'long stretches can all contribute to extra jaw muscle '
              'activity. Noticing the pattern is usually the first step '
              'toward easing it.',
        ),
        ArticleSection(
          heading: 'When to check in with a professional',
          body:
              'Ongoing jaw pain, clicking, or trouble opening your mouth '
              'fully are worth mentioning to a dentist or doctor — this '
              'article is general information, not a substitute for '
              'their guidance.',
        ),
      ],
    ),
    WellnessArticle(
      id: 'jaw_gentle_release_habits',
      topic: WellnessTopic.jawRelaxation,
      title: 'Gentle Habits for an Easier Jaw',
      summary:
          'Small, low-effort habits people use to encourage the jaw '
          'muscles to soften throughout the day.',
      readMinutes: 3,
      tags: ['relaxation', 'breathing', 'habits'],
      sections: [
        ArticleSection(
          heading: 'The "lips together, teeth apart" cue',
          body:
              'A simple resting position — lips gently closed, teeth not '
              'touching, tongue relaxed — is one many people find helpful '
              'to return to during the day, especially while working.',
        ),
        ArticleSection(
          heading: 'Pairing with slow breathing',
          body:
              'Slow, unhurried breathing is often paired with jaw '
              'relaxation, since the two tend to loosen up together. A '
              'few slow breaths can be a natural moment to also notice '
              'and release jaw tension.',
        ),
        ArticleSection(
          heading: 'Warm compresses',
          body:
              'Some people find a warm (not hot) compress held near the '
              'jaw for a few minutes comfortable as part of an evening '
              'wind-down routine.',
        ),
      ],
    ),

    // ---- Neck mobility ---------------------------------------------------
    WellnessArticle(
      id: 'neck_screen_time_habits',
      topic: WellnessTopic.neckMobility,
      title: 'Screens, Posture, and Your Neck',
      summary:
          'Looking down at phones and laptops for long stretches adds '
          'load to the neck. A few habits can help balance it out.',
      readMinutes: 3,
      tags: ['text neck', 'screen time', 'desk'],
      sections: [
        ArticleSection(
          heading: 'Why "text neck" adds up',
          body:
              'The head is heavy, and tilting it forward to look at a '
              'screen increases the effective load your neck muscles '
              'support. A few minutes here and there rarely matters much, '
              'but hours of it, day after day, tends to add up.',
        ),
        ArticleSection(
          heading: 'Simple positioning changes',
          body:
              'Raising a laptop or phone closer to eye level, and taking '
              'short breaks to look up and around, are common, low-effort '
              'ways people reduce sustained forward-neck posture.',
        ),
        ArticleSection(
          heading: 'Movement over stillness',
          body:
              'Staying in any single position for very long — good '
              'posture or not — can leave a neck feeling stiff. Gentle, '
              'regular movement throughout the day is generally more '
              'comfortable than long stretches of stillness.',
        ),
      ],
    ),
    WellnessArticle(
      id: 'neck_range_of_motion_basics',
      topic: WellnessTopic.neckMobility,
      title: 'The Basics of Neck Range of Motion',
      summary:
          'A plain-language look at the directions a neck comfortably '
          'moves in, and why gentle mobility work is popular.',
      readMinutes: 4,
      tags: ['mobility', 'stretching', 'stiffness'],
      sections: [
        ArticleSection(
          heading: 'Four basic directions',
          body:
              'The neck generally moves forward and back, side to side '
              '(ear toward shoulder), and in rotation (looking over each '
              'shoulder). Gentle mobility routines often work through all '
              'four in turn.',
        ),
        ArticleSection(
          heading: 'Slow and controlled beats fast',
          body:
              'Slow, controlled movement through a comfortable range is '
              'generally preferred over quick or bouncy motion, since it '
              'gives the muscles time to ease into the stretch rather '
              'than reacting against it.',
        ),
        ArticleSection(
          heading: 'Stop short of pain',
          body:
              'Mild tension is normal during a stretch; sharp or shooting '
              'pain is not. If a movement hurts, ease off and consider '
              'checking in with a healthcare professional if it '
              'continues.',
        ),
      ],
    ),

    // ---- Healthy posture ---------------------------------------------------
    WellnessArticle(
      id: 'posture_everyday_basics',
      topic: WellnessTopic.healthyPosture,
      title: 'Everyday Posture, in Plain Terms',
      summary:
          'Posture isn\'t about holding one "correct" position all day — '
          'it\'s more about variety and support.',
      readMinutes: 3,
      tags: ['sitting', 'standing', 'ergonomics'],
      sections: [
        ArticleSection(
          heading: 'There\'s no single perfect posture',
          body:
              'Rather than one fixed "correct" posture to hold all day, '
              'most guidance today focuses on regularly changing position '
              'and avoiding long, unbroken stretches in any one posture.',
        ),
        ArticleSection(
          heading: 'Set up your space to help you',
          body:
              'A chair, desk, and screen positioned so you\'re not '
              'reaching, slouching, or craning your neck makes it easier '
              'to sit comfortably without consciously thinking about it.',
        ),
        ArticleSection(
          heading: 'Build in movement breaks',
          body:
              'Standing up, stretching, or walking for a minute every so '
              'often is a simple habit many people use to offset long '
              'periods of sitting or standing still.',
        ),
      ],
    ),
    WellnessArticle(
      id: 'posture_shoulders_and_upper_back',
      topic: WellnessTopic.healthyPosture,
      title: 'Shoulders and Upper Back Awareness',
      summary:
          'Rounded shoulders are common with desk work. Here\'s a gentle '
          'way to think about counterbalancing them.',
      readMinutes: 3,
      tags: ['shoulders', 'upper back', 'rounding'],
      sections: [
        ArticleSection(
          heading: 'Why shoulders round forward',
          body:
              'Reaching toward a keyboard or phone for long periods can '
              'gradually pull the shoulders forward and round the upper '
              'back — a very common pattern with modern desk-based work.',
        ),
        ArticleSection(
          heading: 'Gentle counter-movement',
          body:
              'Many people find it helpful to periodically open the chest '
              'and draw the shoulder blades gently together and down, as '
              'a light counter-movement to hours spent reaching forward.',
        ),
        ArticleSection(
          heading: 'Consistency over intensity',
          body:
              'A brief posture reset done often throughout the day tends '
              'to be more sustainable than a single long session — it\'s '
              'a habit more than a workout.',
        ),
      ],
    ),

    // ---- Hydration ---------------------------------------------------------
    WellnessArticle(
      id: 'hydration_how_much_is_reasonable',
      topic: WellnessTopic.hydration,
      title: 'How Much Water Is "Enough"?',
      summary:
          'The often-repeated "8 glasses a day" rule is a rough '
          'guideline, not a strict target. What actually shapes your needs.',
      readMinutes: 3,
      tags: ['water intake', 'thirst', 'guidelines'],
      sections: [
        ArticleSection(
          heading: 'Needs vary by person',
          body:
              'How much fluid someone needs varies with body size, '
              'activity level, climate, and overall diet (since food '
              'contributes water too). There isn\'t one number that fits '
              'everyone.',
        ),
        ArticleSection(
          heading: 'Thirst is a reasonable guide',
          body:
              'For most healthy adults, drinking when thirsty and having '
              'water regularly available throughout the day is a '
              'reasonable, low-effort approach rather than tracking exact '
              'volumes.',
        ),
        ArticleSection(
          heading: 'Simple signals worth noticing',
          body:
              'Pale yellow urine and rarely feeling thirsty are commonly '
              'cited as easy, everyday signs of adequate hydration. '
              'Persistent thirst, dizziness, or very dark urine are worth '
              'discussing with a doctor.',
        ),
      ],
    ),
    WellnessArticle(
      id: 'hydration_building_the_habit',
      topic: WellnessTopic.hydration,
      title: 'Building a Steady Hydration Habit',
      summary:
          'Small, repeatable habits tend to work better than trying to '
          'drink a large amount all at once.',
      readMinutes: 2,
      tags: ['habits', 'reminders', 'routine'],
      sections: [
        ArticleSection(
          heading: 'Spread it through the day',
          body:
              'Sipping water steadily across the day is generally more '
              'comfortable than trying to catch up with a large amount in '
              'one sitting, especially later in the evening.',
        ),
        ArticleSection(
          heading: 'Anchor it to existing habits',
          body:
              'Keeping a glass or bottle somewhere visible, or pairing a '
              'drink of water with something you already do regularly '
              '(like a meal or a work break), can make the habit easier '
              'to stick to than relying on willpower alone.',
        ),
        ArticleSection(
          heading: 'Other drinks count too',
          body:
              'Tea, milk, and water-rich foods like fruits and vegetables '
              'all contribute to overall fluid intake — water doesn\'t '
              'have to be the only source.',
        ),
      ],
    ),

    // ---- Basic skincare ------------------------------------------------
    WellnessArticle(
      id: 'skincare_simple_routine_basics',
      topic: WellnessTopic.basicSkincare,
      title: 'A Simple Skincare Routine, Explained',
      summary:
          'You don\'t need many steps to look after your skin. Here\'s '
          'what the basics generally cover and why.',
      readMinutes: 4,
      tags: ['cleanser', 'moisturizer', 'routine', 'basics'],
      sections: [
        ArticleSection(
          heading: 'Cleansing',
          body:
              'A gentle cleanser removes dirt, oil, and residue that '
              'build up over the day. Most guidance suggests once or '
              'twice daily is plenty — over-washing can leave skin feeling '
              'dry or tight for some people.',
        ),
        ArticleSection(
          heading: 'Moisturizing',
          body:
              'Moisturizer helps support the skin\'s outer barrier, which '
              'plays a role in keeping it comfortable. Preferences vary a '
              'lot by skin type, so what works well for one person may '
              'not suit another.',
        ),
        ArticleSection(
          heading: 'Sun protection',
          body:
              'Daytime sun protection is widely recommended by '
              'dermatologists as one of the more impactful everyday '
              'habits for skin, alongside cleansing and moisturizing.',
        ),
        ArticleSection(
          heading: 'Keep it simple to start',
          body:
              'A short, consistent routine is generally easier to stick '
              "with than a long one. If you're trying something new or "
              'have sensitive skin, introducing one product at a time '
              'makes it easier to notice how your skin responds.',
        ),
      ],
    ),
    WellnessArticle(
      id: 'skincare_when_to_ask_a_dermatologist',
      topic: WellnessTopic.basicSkincare,
      title: 'When a Dermatologist Is the Right Call',
      summary:
          'General skincare habits go a long way, but some things are '
          'worth a professional opinion rather than trial and error.',
      readMinutes: 2,
      tags: ['dermatologist', 'professional advice'],
      sections: [
        ArticleSection(
          heading: 'This library is general information',
          body:
              'Everything in this app is general educational content, '
              'not a diagnosis or a personalized skincare plan. Skin '
              'varies a great deal from person to person.',
        ),
        ArticleSection(
          heading: 'Signs worth getting checked',
          body:
              'Persistent irritation, unusual changes in a mole or patch '
              'of skin, or a reaction to a new product are all reasonable '
              'reasons to check in with a dermatologist rather than '
              'guessing.',
        ),
        ArticleSection(
          heading: 'A professional can personalize things',
          body:
              'A dermatologist can take your specific skin type, history, '
              'and goals into account in a way general articles like this '
              'one aren\'t able to.',
        ),
      ],
    ),

    // ---- Recovery ------------------------------------------------------
    WellnessArticle(
      id: 'recovery_why_rest_days_matter',
      topic: WellnessTopic.recovery,
      title: 'Why Rest Days Are Part of the Plan',
      summary:
          'Taking a scheduled break isn\'t a lapse — it\'s a normal, '
          'useful part of any regular routine.',
      readMinutes: 3,
      tags: ['rest days', 'recovery', 'consistency'],
      sections: [
        ArticleSection(
          heading: 'Rest is part of the routine, not outside it',
          body:
              'Muscles and habits both benefit from occasional breaks — '
              'a planned rest day is a normal part of a sustainable '
              'routine, not a sign of falling behind.',
        ),
        ArticleSection(
          heading: 'Listening to how you feel',
          body:
              'Ongoing tiredness, soreness, or a general sense of being '
              'run down are reasonable cues to ease off for a day, '
              'independent of whatever schedule you had planned.',
        ),
        ArticleSection(
          heading: 'Consistency over streaks',
          body:
              'A routine that includes rest tends to be easier to stick '
              'with over months than one that never lets up — long-term '
              'consistency matters more than never missing a day.',
        ),
      ],
    ),
    WellnessArticle(
      id: 'recovery_sleep_basics',
      topic: WellnessTopic.recovery,
      title: 'Sleep\'s Role in Feeling Recovered',
      summary:
          'Sleep is one of the more consistent factors people mention '
          'when describing what makes them feel recovered day to day.',
      readMinutes: 3,
      tags: ['sleep', 'wind down', 'rest'],
      sections: [
        ArticleSection(
          heading: 'A wind-down routine',
          body:
              'A consistent, calming pattern before bed — dimming '
              'lights, stepping away from screens, some light stretching '
              '— is a common way people signal to themselves that the day '
              'is winding down.',
        ),
        ArticleSection(
          heading: 'Consistency in timing',
          body:
              'Going to bed and waking up around similar times each day '
              'is frequently mentioned as more helpful for feeling rested '
              'than the exact number of hours alone.',
        ),
        ArticleSection(
          heading: 'If sleep is a persistent struggle',
          body:
              'Ongoing trouble falling or staying asleep is worth raising '
              'with a doctor — general habit tips like these are a '
              'starting point, not a treatment.',
        ),
      ],
    ),
  ];

  /// All articles under [topic], preserving their original order.
  static List<WellnessArticle> byTopic(WellnessTopic topic) =>
      articles.where((article) => article.topic == topic).toList();
}
