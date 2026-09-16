# Easy Schengen

Easy Schengen is a small SwiftUI iOS app for planning Schengen travel under the 90/180 rule.

## What it does

- Add past or future trips with entry and exit dates.
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
