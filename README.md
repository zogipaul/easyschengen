# Easy Schengen

Easy Schengen is a small SwiftUI iOS app for planning Schengen travel under the 90/180 rule.

## What it does

- Add past or future trips with entry and exit dates and an optional Schengen country, using a searchable destination picker.
- See all-time travel stats through today: trips started, distinct countries visited, and unique travel days. Future trips are excluded, ongoing stays count only through today, and overlapping days count once. Existing trips without a destination still load and can be updated.
- Look forward to the nearest upcoming trip with a prominent countdown on the home screen.
- Add a small or medium Home Screen widget that counts down to the next EU trip.
- Count travel days inclusively, matching Schengen day counting.
- Show used days, available days today, and the last day available if staying continuously from today.
- Render a month calendar with trip days, available days, blocked days, and today. The latest-exit marker uses the current trip, otherwise the next planned trip, and falls back to entry today when neither exists.
- Show the entry date behind the calendar and trip-editor allowance checks; label the separate home-screen forecast as a continuous stay from today.
- Save trips locally in an App Group shared by the app and widget.

## Open in Xcode

Open `EasySchengen.xcodeproj`, choose the shared `EasySchengen` scheme, and run on an iPhone simulator.

This workspace was created with the active developer directory pointing at Command Line Tools, so a simulator build needs full Xcode selected with `xcode-select`.

## Calendar regression checks

Run the Foundation-only checks without a simulator:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc EasySchengen/Models/Trip.swift EasySchengen/Models/SchengenCalculator.swift Tests/CalendarStayContextTests.swift -o /private/tmp/easyschengen-calendar-tests
/private/tmp/easyschengen-calendar-tests
```

## Destination and statistics checks

The country list follows the [Council of the EU's Schengen membership list](https://www.consilium.europa.eu/en/policies/schengen-area/) (29 countries, checked 25 October 2026). For a journey across multiple countries, record each country's dates as a separate trip; shared travel days still count once.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc EasySchengen/Models/Trip.swift EasySchengen/Models/TravelStatistics.swift EasySchengen/Models/SchengenCalculator.swift Tests/TravelStatisticsTests.swift -o /private/tmp/easyschengen-statistics-tests
/private/tmp/easyschengen-statistics-tests
```

## QA and performance checks

Run all Foundation regression checks (including 2,400 deterministic comparisons against an independent day-by-day reference in four time zones):

```sh
./scripts/qa.sh
./scripts/qa.sh --benchmark
```

The benchmark compiles with `-O` and measures calculator construction, dashboard summaries, a month of day evaluations and ten editor forecasts, averaged over ten iterations. On the development Mac on 25 October 2026, the 100-trip fixture went from **23.1 ms to 4.7–5.4 ms** per workload. These are local model timings, not device frame-rate measurements. The century-long stress fixture went from 231.6 ms to 0.5–0.9 ms; independent inclusive-range checks also caught an old day-enumeration error across historical time-zone changes.

The calculator now merges trip ranges instead of expanding every travel day. Dashboard results refresh when trips change, the app becomes active, or iOS reports a significant time change (including midnight/time-zone changes); month navigation and appearance changes reuse them. Editor forecasts refresh when entry dates or other trips change. Trip rows load lazily.

QA fixes: opening a trip no longer silently shortens its exit date; invalid dates remain visible and saving is disabled until corrected. Over-limit calendar days show a warning color and expose exact used/remaining counts to accessibility. Accessibility text sizes use stacked hero/date layouts. Widget and app versions are aligned.

Simulator QA covered the dashboard, calendar-to-editor navigation, valid/invalid exit selection and maximum text-size layout. Debug/Release builds include the widget. Foundation coverage includes legacy JSON, country round trips, statistics, overlap, inclusive 90/180 boundaries, leap years, DST and long date ranges. Physical-device Instruments profiling and a full App Store archive remain separate release checks.
