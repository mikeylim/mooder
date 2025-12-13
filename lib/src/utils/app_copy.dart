// app_copy.dart
/// Centralized micro-copy for the app.
/// Keep tone: calm, human, non-judgmental, supportive.
class AppCopy {
  // ---- App ----
  static const appName = 'Mooder';

  // ---- Auth ----
  static const welcomeBackTitle = 'Welcome back';
  static const welcomeBackSubtitle =
      'Sign in to view your check-ins, suggestions, and insights.';

  static const signIn = 'Sign in';
  static const signOut = 'Sign out';
  static const createAccount = 'Create account';
  static const createAccountLink = 'New here? Create an account';

  static const emailLabel = 'Email';
  static const emailHint = 'you@example.com';
  static const passwordLabel = 'Password';
  static const passwordHelper = 'At least 6 characters';

  // ---- Auth errors ----
  static const errEnterEmailPassword = 'Enter both email and password.';
  static const errInvalidEmail = 'Please enter a valid email.';
  static const errWrongPassword = 'That password doesn’t match.';
  static const errUserNotFound = 'No account found with that email.';
  static const errPasswordMin6 = 'Password must be at least 6 characters.';
  static const errTooManyRequests = 'Too many attempts. Try again in a bit.';
  static const errNetwork =
      'Network error. Check your connection and try again.';
  static const errGeneric = 'Something went wrong. Please try again.';

  // ---- Auth (extra) ----
  static const signupTitle = 'Create your account';
  static const signupSubtitle =
      'This lets you save check-ins, suggestions, and insights.';
  static const errEmailPasswordRequired = 'Email and password are required.';
  static const errEmailInUse = 'An account already exists with that email.';
  static const errWeakPassword =
      'Use a stronger password (at least 6 characters).';
  static const errSignInFailed = 'Couldn’t sign in. Please try again.';
  static const errSignupFailed =
      'Couldn’t create your account. Please try again.';

  // ---- Home ----
  static const startCheckIn = 'Start check-in';
  static const viewHistory = 'View history';
  static const viewInsights = 'View insights';
  static const lastCheckInLabel = 'Last check-in';
  static const lastCheckInNever = 'No check-ins yet';
  static const lastCheckInToday = 'Today';
  static const lastCheckInYesterday = 'Yesterday';

  // ---- Check-in ----
  static const checkInTitle = 'Mood check-in';
  static const stepPrefix = 'Step';

  static const moodQuestion = 'How do you feel right now?';
  static const moodTip =
      'Pick the closest mood — it doesn’t have to be perfect.';

  static const intensityLabel = 'Intensity';
  static const energyLabel = 'Energy level';
  static const quickCheckTitle = 'Quick check (optional)';
  static const focusLabel = 'Focus';
  static const connectionLabel = 'Connection';
  static const tensionLabel = 'Physical tension';

  static const driversTitle = 'What’s driving this? (Pick up to 3)';
  static const driversNone = '(none selected)';

  static const safetyTitle = 'Safety check';
  static const safetySubtitle = 'Are you having thoughts of hurting yourself?';

  static const saveCheckIn = 'Save check-in';
  static const next = 'Next';
  static const back = 'Back';

  // ---- Result ----
  static const resultTitle = 'Your check-in';
  static const getSuggestions = 'Get suggestions';
  static const backToHome = 'Back to home';
  static const safetyEnabled = '⚠ Safety mode is enabled for this check-in.';

  // ---- Suggestions ----
  static const suggestionsTitle = 'Suggestions';
  static const suggestionsHint =
      'Choose a category to see ideas that fit how you’re feeling.';

  static const loadedFromSaved = 'Loaded from saved suggestions';
  static const generatedNow = 'Generated now and saved';
  static const safetyDisabledSuggestions =
      'Safety mode: suggestions are disabled for this check-in.';

  // ---- History ----
  static const historyTitle = 'History';
  static const noHistory = 'No check-ins yet';

  static const historyDetailsTitle = 'Check-in details';
  static const savedSuggestions = 'Saved suggestions';

  // ---- Insights ----
  static const insightsTitle = 'Insights';
  static const noInsights7 = 'No check-ins in the last 7 days.';
  static const noInsights30 = 'No check-ins in the last 30 days.';

  static const insightsRange7 = '7 days';
  static const insightsRange30 = '30 days';
  static const insightsLast7 = 'Last 7 days';
  static const insightsLast30 = 'Last 30 days';

  static const insightsSummaryTitle = 'Summary';
  static const insightsTrendTitle = 'Trend';
  static const insightsCommonMoodsTitle = 'Most common moods (Top 5)';
  static const insightsCommonDriversTitle = 'Most common drivers (Top 5)';

  static const insightsCheckinsLabel = 'Check-ins';
  static const insightsAvgEnergyLabel = 'Avg Energy';
  static const insightsAvgTensionLabel = 'Avg Tension';
  static const insightsAvgFocusLabel = 'Avg Focus';
  static const insightsAvgConnectionLabel = 'Avg Connection';

  static const insightsNoDriversYet = 'No drivers recorded yet.';
  static const insightsNotEnoughData =
      'Not enough data yet (need at least 2 check-ins).';

  // ✅ Trend legend labels
  static const insightsLegendEnergy = 'Energy';
  static const insightsLegendTension = 'Tension';
  static const insightsLegendIntensity = 'Intensity';
  static const insightsLegendFocus = 'Focus';
  static const insightsLegendConnection = 'Connection';

  // ✅ Optional helper copy for driver breakdown UI
  static const insightsTopDriversLabel = 'Top 5';
  static const insightsOtherDriversLabel = 'Other';

  // --- Common buttons ---
  static const cancel = 'Cancel';
  static const delete = 'Delete';
  static const deleteAll = 'Delete all';
  static const edit = 'Edit';
  static const more = 'More';
  static const deleted = 'Deleted.';
  static const unknown = 'Unknown';

  // --- History delete copy ---
  static const deleteOneTitle = 'Delete this check-in?';
  static const deleteOneBody = 'This can’t be undone.';
  static const deleteAllTitle = 'Delete all history?';
  static const deleteAllBody = 'This deletes all check-ins permanently.';
  static const deleteAllHistory = 'Delete all history';
  static const historyDeleted = 'History deleted.';

  // --- Check-in UX ---
  static const errPickUpTo3Drivers = 'Choose up to 3.';
  static const reviewTitle = 'Review';
  static const safetyWillEnable =
      '⚠ Safety mode will be enabled for this check-in.';

  // --- Slider helpers (0–10 scale) ---
  static const scaleHintIntensity = '0 = none • 10 = as strong as it gets';
  static const scaleHintEnergy = '0 = drained • 10 = energized';
  static const scaleHintFocus = '0 = scattered • 10 = locked in';
  static const scaleHintConnection = '0 = isolated • 10 = connected';
  static const scaleHintTension = '0 = relaxed • 10 = very tense';
}
