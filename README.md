# CleanEater

A cross-platform nutrition tracker built with Flutter. Tracks daily calorie and macro intake, generates personalised diet plans using the Mifflin-St Jeor TDEE formula, and recommends healthier food swaps using a weighted Euclidean distance algorithm.

Targets Windows desktop (primary development platform), Android, and iOS.

---

## Features

- **Daily food log** — log meals by slot (breakfast, lunch, dinner, snack), view a donut chart of calories consumed vs goal, and track protein, fat, and carb targets with per-macro ring charts
- **Diet plan page** — TDEE calculator with persistent inputs, weight-loss goal selector (maintain / -0.25 / -0.5 / -1.0 kg/week), macro preset ratios, and a Smart Swap engine that suggests nutritionally similar but healthier alternatives
- **Food history** — 7-day bar chart and a full grouped log with colour-coded meal slots
- **Profile page** — streak counter, weekly hit rate, 3-week rolling nutrition insights, projected monthly weight change, and editable goals
- **QnA page** — FAQ section, food search with a full per-100g nutrition breakdown, and an ask-the-expert form
- **Barcode scanner** — available on Android and iOS (disabled on desktop)
- **Tiered food data** — 250 curated foods bundled offline, USDA FoodData Central API as a fallback (requires a free API key)

---

## Prerequisites

- Flutter SDK 3.x or later — [install guide](https://docs.flutter.dev/get-started/install)
- For Android builds: Android Studio with SDK tools
- For iOS builds: Xcode (macOS only)
- For Windows builds: Visual Studio with the "Desktop development with C++" workload

Verify your environment:

```
flutter doctor
```

---

## Running the app

Clone the repo and install dependencies first:

```bash
git clone https://github.com/MatejPechoucek/scenario2project
cd scenario2project
flutter pub get
```

### Windows (primary)

```bash
# If a previous instance is running, kill it first (Windows locks the .exe)
taskkill /F /IM scenario2project.exe

flutter run -d windows
```

### Android

```bash
flutter run -d android
```

### iOS (macOS only)

```bash
flutter run -d ios
```

---

## USDA API key setup

Food search falls back to the USDA FoodData Central API when local results are limited. The key is not committed to the repo. Create the file manually:

**`lib/config/api_config.dart`**

```dart
library;
const String kUsdaApiKey     = 'YOUR_KEY_HERE';
const String kUsdaBaseUrl    = 'https://api.nal.usda.gov/fdc/v1';
const int kNutrientIdEnergy  = 1008;
const int kNutrientIdProtein = 1003;
const int kNutrientIdFat     = 1004;
const int kNutrientIdCarbs   = 1005;
const int kNutrientIdSugar   = 2000;
const int kNutrientIdSodium  = 1093;
const int kNutrientIdFiber   = 1079;
```

Get a free key at [api.data.gov/signup](https://api.data.gov/signup). Without it the app still works using the 250 bundled foods only.

---

## First launch

On first run the app:

1. Creates a local SQLite database and runs all migrations
2. Seeds a default user profile (name, calorie goal, macro targets, TDEE inputs)
3. Seeds 21 days of placeholder food log entries so charts and history are populated from the start

To reset to a clean state, delete the database file:

```
.dart_tool/sqflite_common_ffi/databases/diet_plan.db
```

---

## Project structure

```
lib/
├── main.dart                             — entry point, splash screen, bottom nav shell
├── config/
│   └── api_config.dart                   — USDA API key (gitignored)
├── database/
│   ├── app_user.dart                     — single local user model
│   ├── meal.dart                         — diet plan meal model
│   ├── food_item.dart                    — food bank entry model (per 100g)
│   ├── food_log_entry.dart               — consumed food entry model
│   └── db_helper.dart                    — SQLite v6, all tables, CRUD, migrations, seed data
├── services/
│   ├── usda_api_service.dart             — USDA FoodData Central HTTP client
│   └── food_repository.dart              — tiered food lookup (bundled → cache → API)
├── algorithm/
│   └── nutritional_proximity.dart        — Smart Swap weighted distance engine
├── pages/
│   ├── homepage/home_page.dart           — daily tracker
│   ├── dietpage/
│   │   ├── diet_page.dart                — TDEE calculator, meal plan, Smart Swap, history
│   │   └── calorie_calculator.dart       — Mifflin-St Jeor formula
│   ├── foodsearch/food_search_page.dart  — food search and log screen
│   ├── profilepage/profile_page.dart     — stats, insights, goals editor
│   └── qnapage/qna_page.dart             — FAQ, food search, barcode scanner
└── widgets/
    ├── int_spinner_field.dart             — numeric spinner with persistent initial value
    └── smart_swap_panel.dart              — Smart Swap UI panel

assets/
└── data/
    └── base_foods.json                   — 250 curated foods (offline, Tier 1)
```

---

## Branch workflow

Do not commit directly to `master`. Create a branch for your work:

```bash
git checkout -b your-name/feature-description
git push origin your-name/feature-description
```

Open a pull request when ready for review.

---

## Dependencies

| Package | Purpose |
|---|---|
| `fl_chart` | Pie and bar charts |
| `sqflite` + `sqflite_common_ffi` | SQLite on mobile and desktop |
| `http` | USDA API requests |
| `path` | Database file path resolution |
| `mobile_scanner` | Barcode scanning (Android/iOS only) |
