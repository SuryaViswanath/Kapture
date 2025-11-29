# Kapture — Offline-first Photography Learning App

Kapture is a lightweight, offline-first mobile app that helps photography enthusiasts learn by doing. Users create multi-day challenge tracks (Street, Portrait, Landscape, Wildlife, etc.), complete daily photo tasks, submit three photos for automated evaluation (VLM), and progress through the track with guided subtasks and tips.

Target audience: people interested in photography who want structured, practical practice and automated feedback.

---

## Highlights / Features

- Create personalized multi-day photography tracks (3–21 days).
- LLM-generated daily challenges (title, task, tips, step-by-step subtasks).
- Offline-capable LLM (Cactus) for plan generation with deterministic prompts.
- Photo evaluation via Gemini (VLM) — image-aware feedback saved in DB.
- Local SQLite storage for users, tracks, challenges, submissions, feedback, subtasks and chat.
- In-app chat assistant (context-aware) to help complete the current challenge.
- Clean, minimal UI with progress and streaks.

---

## Quick Start

Prerequisites
- Flutter SDK (>= 3.0)
- Device/emulator (Android / iOS)
- (Optional) Gemini API key for photo evaluation (recommended for feedback)
- Note: local LLM model files are downloaded at runtime by the app (may be large)

Install & Run
```bash
git clone <repo-url>
cd kapture
flutter pub get
flutter run
```

If you want to run only the AI test screen (dev helper):
```bash
flutter run -t lib/screens/ai_test_screen.dart
```

---

## Important Configuration

- Gemini API key: used by `lib/services/gemini_evaluator.dart`. Create a simple env config file (not committed):

lib/config/env_config.dart
```dart
class EnvConfig {
  // Add your Gemini API key here (or load from secure storage)
  static const String geminiApiKey = 'YOUR_GEMINI_API_KEY';
}
```

- Local LLM (Cactus): the app downloads and initializes a model (example: `qwen3-0.6`) on first run via `LearningManager`. Ensure device has enough storage and network when first generating tracks.

---

## Project Structure (key files)

- lib/
  - main.dart (app entry) — (if present)
  - screens/
    - home_screen.dart — main dashboard, challenge carousel, start/continue logic
    - active_track_screen.dart — view challenge, subtasks, submit photos, see feedback
    - new_track_screen.dart — create a new track (uses LLM)
    - ai_test_screen.dart — dev screen to test LLM outputs
    - chat_screen.dart — in-app LLM chat assistant
    - feedback_screen.dart — feedback display after evaluation
  - services/
    - learning_manager.dart — generates plans & per-day challenges using Cactus LLM
    - gemini_evaluator.dart — evaluates submitted photos using Gemini API (VLM)
    - photo_evaluator.dart — wrapper / helper used elsewhere (if present)
    - track_service.dart — reads/writes Tracks & returns current/next challenges
    - database_helper.dart — SQLite DB setup & migrations
    - subtask_service.dart — get/toggle subtasks
    - chat_service.dart — store and load chat messages
  - models/
    - user.dart, track.dart, challenge.dart, subtask.dart, etc.
  - theme/
    - app_theme.dart — centralized colors and styles
  - assets/
    - images/, icons/ (static assets and screenshots)

---

## Data model overview

(Fields are approximate — check model files for exact names)

- users: id, username, email, photographyStyles (list), skillLevel, createdAt
- tracks: id, user_id, name, style, level, durationDays, is_active, created_at
- challenges: id, track_id, day_number, title, description, tips (string), completed, completed_at
- subtasks: id, challenge_id, title, order_index, completed
- submissions: id, challenge_id, photo_paths (csv), submitted_at, validated
- feedback: id, submission_id, validation_result (json), technical_notes, suggestions, created_at
- chat_messages: id, user_id, role, content, created_at

---

## How it works (high level)

1. Create a new track in `NewTrackScreen` — triggers `LearningManager.generatePlan`.
2. `LearningManager` downloads/initializes a Cactus LLM and generates per-day challenges using a strict prompt. Each challenge includes: TITLE, TASK, TIP1–3, STEP1–4 (subtasks).
3. Generated plan is saved to local SQLite via `LearningManager._savePlanToDatabase`.
4. On Home, track cards use `TrackService.getCurrentDayNumber` to show "Start" or "Continue" and to retrieve the current/next challenge.
5. Open a challenge in `ActiveTrackScreen`: follow subtasks, capture up to 3 photos, submit for evaluation.
6. Submission calls `GeminiEvaluator.evaluatePhotos` which posts images + prompt to the Gemini API and returns feedback.
7. Submission and feedback are saved to the DB; completed challenge is marked; on completion the UI navigates to next uncompleted challenge automatically.

---

## LLM / VLM details & prompts

- LLM for challenge generation: `LearningManager` uses CactusLM and a strict system + user prompt that demands exact formatting (TITLE, TASK, TIP1..STEP4). Keeping the prompt strict improves parsing reliability.
- VLM for evaluation: `GeminiEvaluator` sends images and a structured evaluation prompt covering overall assessment, per-photo comments, strengths, improvements, technical and creative feedback, and next steps.
- If Gemini is unavailable, evaluation will fail gracefully; app stores submission and marks validated maybe false (see `GeminiEvaluator` error handling).

---

## Troubleshooting

- Large model download: first plan generation may download LLM model; ensure enough disk space and good network.
- Gemini API errors: check `lib/config/env_config.dart` and ensure key is valid and has billing enabled for the endpoint.
- Parsing issues: raw LLM output is printed in logs. Use `ai_test_screen.dart` to iterate quickly on the prompt.

---

## Contributing

Contributions welcome. Suggested workflow:
1. Fork the repo
2. Create a branch: `feature/your-feature`
3. Run and test locally
4. Open a PR describing changes

Please keep LLM prompt changes and regex parsing in sync.

