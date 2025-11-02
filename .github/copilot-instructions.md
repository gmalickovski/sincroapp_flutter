### Quick context

- This is a Flutter app that uses Firebase heavily (Auth, Firestore, Functions, App Check).
- Top-level entry: `lib/main.dart` — it initializes Firebase, conditionally connects to local emulators in debug, and activates App Check in release.
- AI/ML integration: `lib/services/ai_service.dart` uses `firebase_ai` (Vertex AI) and requires a signed-in `FirebaseAuth.instance.currentUser` and App Check to be configured.
- Firestore access patterns are centralized in `lib/services/firestore_service.dart`. Documents live under `users/{uid}/...` (tasks, goals, journalEntries, tags).

### What makes changes safe / basic contract

- Small UI or service changes should preserve UTC timestamp handling: DateTimes stored as UTC and Firestore `Timestamp` objects (see `FirestoreService` conversion helpers).
- AI flows expect the model to return a JSON array of objects. When working on `ai_service`/`ai_prompt_builder`, follow the existing parsing safeguards (strip fences, regex to extract array, validate YYYY-MM-DD dates).

### Important patterns & gotchas (do not break)

- Emulator behavior: in `lib/main.dart` the app auto-connects to emulators when `kDebugMode` is true. Emu host uses `10.0.2.2` for Android emulator and `localhost` otherwise. Ports: Firestore(8081), Auth(9098), Functions(5002).
- App Check + Auth: 
  - `AIService._getModel()` requires an authenticated Firebase user and App Check in many flows — changes to auth or App Check must preserve checks or provide clear alternate behavior
  - Web mode: requires reCAPTCHA v3 with site key, see `kReCaptchaSiteKey` in `main.dart`
  - Debug tokens must be registered in Firebase Console > App Check for testing
- Date handling: 
  - Code intentionally converts DateTimes to UTC and stores only date parts for `dueDate`, `createdAt`, `recurrenceEndDate`
  - Due dates are stored with time set to midnight UTC to ensure date-only comparison works
  - Keep this convention when creating/updating Firestore fields
- Data Models & IDs:
  - Firestore documents self-reference their IDs (`docRef.update({'id': docRef.id})`). Keep this pattern when creating new documents
  - Write batch operations are preferred for bulk updates (see `deleteTasks`, `addRecurringTasks` in `FirestoreService`)
  - Use `toFirestore`/`fromFirestore` methods consistently for data conversion
- String & ID handling:
  - `StringSanitizer.toSimpleTag(...)` creates deterministic IDs for tags and goals
  - The `sanitizedTitle` field in goals is derived from the title but preserved in storage
  - Tag documents use sanitized names as IDs for consistency

### AI specific guidance (high priority)

- When editing or testing `lib/services/ai_service.dart` or `lib/services/ai_prompt_builder.dart`:
  - Model configuration:
    - Uses Vertex AI via `firebase_ai` with `gemini-2.5-flash-lite` model
    - Caches model instance in `_cachedModel` - reuse this cache
    - Requires both Auth user and App Check tokens to initialize
  - Output format & validation:
    - Prompts MUST request array of JSON objects with `title` and `date` (YYYY-MM-DD)
    - Response processing: strips markdown fences → regex extracts first `[{...}]` array
    - All dates are validated for future/today and correct format before acceptance
  - Error handling:
    - App Check errors: provide clear guidance to register debug tokens
    - Auth errors: direct users to login/retry
    - Malformed responses: suggest retrying or rephrasing
    - Model errors: distinguish between API issues (quota/permission) vs data issues
  - Numerology integration:
    - AI prompts incorporate user's personal numerology data for contextual responses
    - See `AIPromptBuilder.buildTaskSuggestionPrompt()` for required numerology context

### Files to inspect when making changes

- App bootstrap & environment: `lib/main.dart`, `firebase_options.dart`, `firebase.json` (emulator config)
- Firebase / Firestore logic: `lib/services/firestore_service.dart`
- AI flows & prompts: `lib/services/ai_service.dart`, `lib/services/ai_prompt_builder.dart`
- Models and parsers: `lib/features/*/models/*` and `lib/features/tasks/utils/task_parser.dart`
- UI routing & auth: `lib/features/authentication/...` and `lib/app/routs/`

### Developer workflows & commands (typical)

- Install deps: `flutter pub get`
- Run on device/emulator (debug w/ emulators auto-connected):
  - `flutter run` (emulators are connected automatically in debug as implemented in `main.dart`)
- Run web where App Check matters: use browser devtools to get the App Check debug token and register it in Firebase Console when debugging.
- Tests: `flutter test` (repo has `flutter_test` dev dependency).

### Small PR checklist for contributors

- Preserve UTC date conventions and Firestore schemas (look at existing `toFirestore`/`fromFirestore` usages).
- If changing or adding cloud calls (Vertex AI / Functions), update error handling to include App Check/Auth troubleshooting hints.
- When touching AI prompt text, include unit test or a small harness that verifies the JSON-extraction logic (strip fences and regex extraction) to avoid silent parsing failures.

### If you need more context

- Read `lib/main.dart` first to understand emulator/App Check behavior.
- Check `lib/services/firestore_service.dart` for how collections/documents are named and how timestamps/IDs are managed.
- Inspect `lib/services/ai_service.dart` + `ai_prompt_builder.dart` to see the exact expected model input and output format.

If any of these sections are unclear or you want the instructions expanded (for CI, GH Actions, or contributor labels), tell me which part to refine.
