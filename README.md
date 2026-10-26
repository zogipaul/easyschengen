# Easy Schengen

Easy Schengen is a small SwiftUI iOS app for planning Schengen travel under the 90/180 rule.

## What it does

- Add past or future trips with entry and exit dates and any number of Schengen countries, using a searchable multi-select picker. Touch and hold a trip to edit or delete it.
- See all-time travel stats through today: trips started, distinct countries visited, and unique travel days. Future trips are excluded, ongoing stays count only through today, and overlapping days count once. Existing trips without a destination still load and can be updated.
- Look forward to the nearest upcoming trip with a prominent countdown on the home screen.
- Add a small or medium Home Screen widget that counts down to the next EU trip.
- Count travel days inclusively, matching Schengen day counting.
- Show used days, available days today, and the last day available if staying continuously from today.
- Render a month calendar with trip days, available days, blocked days, and today. The latest-exit marker uses the current trip, otherwise the next planned trip, and falls back to entry today when neither exists.
- Show the entry date behind the calendar and trip-editor allowance checks; label the separate home-screen forecast as a continuous stay from today.
- Save trips locally in an App Group shared by the app and widget. Trips are stored as calendar days (`yyyy-MM-dd`), so they keep their dates when the device changes time zone. Older payloads (instants plus one optional country) are migrated on first load.
- If stored data cannot be read, readable trips are still shown, the original bytes are kept under `easy-schengen.trips.unreadable-backups`, and the user sees a warning instead of silently losing data.
- English and German, via `EasySchengen/Localizable.xcstrings` (shared with the widget). Country names follow the device language.

## Open in Xcode

Open `EasySchengen.xcodeproj`, choose the shared `EasySchengen` scheme, and run on an iPhone simulator.

This workspace was created with the active developer directory pointing at Command Line Tools, so a simulator build needs full Xcode selected with `xcode-select`.

## Tests

The `EasySchengenTests` unit-test target (part of the shared scheme, so ⌘U works in Xcode) covers the calculator against an independent day-by-day oracle in four time zones, calendar stay context, statistics, storage migration, time-zone independence and recovery from unreadable data.

The country list follows the [Council of the EU's Schengen membership list](https://www.consilium.europa.eu/en/policies/schengen-area/) (29 countries, checked 25 October 2026).

## QA and performance checks

Run the test target on a simulator (override the device with `QA_DESTINATION`), optionally followed by the calculator benchmark:

```sh
./scripts/qa.sh
./scripts/qa.sh --benchmark
```

The benchmark compiles with `-O` and measures calculator construction, dashboard summaries, a month of day evaluations and ten editor forecasts, averaged over ten iterations. On the development Mac on 25 October 2026, the 100-trip fixture went from **23.1 ms to 4.7–5.4 ms** per workload. These are local model timings, not device frame-rate measurements. The century-long stress fixture went from 231.6 ms to 0.5–0.9 ms; independent inclusive-range checks also caught an old day-enumeration error across historical time-zone changes. Since switching to calendar-day ordinals (26 October 2026), both fixtures take about 0.25 ms.

The calculator now merges trip ranges instead of expanding every travel day. Dashboard results refresh when trips change, the app becomes active, or iOS reports a significant time change (including midnight/time-zone changes); month navigation and appearance changes reuse them. Editor forecasts refresh when entry dates or other trips change. Trip rows load lazily.

QA fixes: opening a trip no longer silently shortens its exit date; invalid dates remain visible and saving is disabled until corrected. Over-limit calendar days show a warning color and expose exact used/remaining counts to accessibility. Accessibility text sizes use stacked hero/date layouts. Widget and app versions are aligned.

Simulator QA covered the dashboard, calendar-to-editor navigation, valid/invalid exit selection and maximum text-size layout. Debug/Release builds include the widget. Foundation coverage includes legacy JSON, country round trips, statistics, overlap, inclusive 90/180 boundaries, leap years, DST and long date ranges. Physical-device Instruments profiling and a full App Store archive remain separate release checks.
