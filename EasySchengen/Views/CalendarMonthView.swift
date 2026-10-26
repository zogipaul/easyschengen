import SwiftUI

struct CalendarMonthView: View {
    var month: Date
    var today: Date
    var calculator: SchengenCalculator
    var lastContinuousDay: Date?
    var nextPossibleEntryDate: Date?
    var onSelectDate: (Date) -> Void

    private let calendar = Calendar.schengen
    private let daySpacing: CGFloat = 5
    // Flexible columns let the grid size its own height, so it never clips
    // at large text sizes or on narrow screens.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 32, maximum: 44), spacing: daySpacing), count: 7)
    }

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols.indices, id: \.self) { index in
                    Text(weekdaySymbols[index])
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .accessibilityHidden(true)

            LazyVGrid(columns: columns, spacing: daySpacing) {
                ForEach(Array(calculator.monthDates(containing: month).enumerated()), id: \.offset) { _, date in
                    if let date {
                        let evaluation = calculator.evaluation(for: date, lastContinuousDay: lastContinuousDay)
                        Button {
                            onSelectDate(date)
                        } label: {
                            CalendarDayCell(
                                evaluation: evaluation,
                                isToday: calendar.isDate(date, inSameDayAs: today),
                                isNextPossibleEntry: calendar.isDate(date, inSameDayAs: nextPossibleEntryDate ?? .distantPast)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens trip planning with this entry date")
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }
}

private struct CalendarDayCell: View {
    var evaluation: DayEvaluation
    var isToday: Bool
    var isNextPossibleEntry: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(backgroundColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: (evaluation.isLastContinuousDay || isNextPossibleEntry) ? 2.5 : 1.2)
                }

            Text("\(Calendar.schengen.component(.day, from: evaluation.date))")
                .font(.system(size: 14, weight: isToday ? .bold : .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var backgroundColor: Color {
        if !evaluation.canBeSchengenDay {
            return .unavailable.opacity(0.18)
        }

        if evaluation.isTripDay {
            return .trip.opacity(0.23)
        }

        if evaluation.canBeSchengenDay {
            return .available.opacity(0.11)
        }

        return .unavailable.opacity(0.10)
    }

    private var borderColor: Color {
        if evaluation.isLastContinuousDay {
            return .lastDay
        }

        if isToday {
            return .ink.opacity(0.75)
        }

        if evaluation.isTripDay {
            return .trip.opacity(0.7)
        }

        if isNextPossibleEntry {
            return .available
        }

        return Color.appBorder
    }

    private var accessibilityLabel: String {
        let status: String
        if evaluation.isTripDay {
            status = evaluation.canBeSchengenDay
                ? String(localized: "planned trip day")
                : String(localized: "planned trip day, exceeds allowance")
        } else if isNextPossibleEntry {
            status = String(localized: "next possible entry date, available Schengen day")
        } else if evaluation.canBeSchengenDay {
            status = String(localized: "available Schengen day")
        } else {
            status = String(localized: "not available")
        }

        var parts = [evaluation.date.formatted(date: .complete, time: .omitted), status]
        if evaluation.isLastContinuousDay {
            parts.append(String(localized: "latest possible exit for the displayed entry date"))
        }
        parts.append(String(localized: "\(evaluation.usedDays) days used"))
        parts.append(String(localized: "\(evaluation.remainingDays) days remaining"))
        return parts.joined(separator: ", ")
    }
}

struct LegendView: View {
    var nextPossibleEntryDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    LegendItem(color: .trip, text: "Trip")
                    LegendItem(color: .available, text: "Available")
                    LegendItem(color: .unavailable, text: "Unavailable")
                    LegendItem(color: .lastDay, text: "Latest exit", outlined: true)
                }
            }

            if let nextPossibleEntryDate = nextPossibleEntryDate {
                Label(
                    "Next possible entry: \(nextPossibleEntryDate.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "arrow.right.circle.fill"
                )
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.available)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LegendItem: View {
    var color: Color
    var text: LocalizedStringKey
    var outlined = false

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(outlined ? Color.clear : color.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(color, lineWidth: outlined ? 2 : 0)
                )
                .frame(width: 13, height: 13)

            Text(text)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.appElevatedSurface, in: Capsule())
    }
}
