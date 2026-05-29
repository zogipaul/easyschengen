import SwiftUI

struct CalendarMonthView: View {
    var month: Date
    var today: Date
    var calculator: SchengenCalculator
    var lastContinuousDay: Date?
    var nextPossibleEntryDate: Date?
    var onSelectDate: (Date) -> Void

    private let calendar = Calendar.schengen
    private let daySpacing: CGFloat = 6
    private let calendarHeight: CGFloat = 336

    var body: some View {
        GeometryReader { proxy in
            let cellSize = max(32, min(42, floor((proxy.size.width - (daySpacing * 6)) / 7)))
            let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: daySpacing), count: 7)

            VStack(spacing: 10) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(weekdaySymbols, id: \.self) { weekday in
                        Text(weekday)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: cellSize)
                    }
                }

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
                                    isNextPossibleEntry: calendar.isDate(date, inSameDayAs: nextPossibleEntryDate ?? .distantPast),
                                    size: cellSize
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens trip planning with this entry date")
                        } else {
                            Color.clear
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: calendarHeight)
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
    var size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .overlay {
                    Circle()
                        .strokeBorder(borderColor, lineWidth: (evaluation.isLastContinuousDay || isNextPossibleEntry) ? 2.5 : 1.2)
                }

            Text("\(Calendar.schengen.component(.day, from: evaluation.date))")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var backgroundColor: Color {
        if evaluation.isTripDay {
            return .trip.opacity(0.35)
        }

        if evaluation.canBeSchengenDay {
            return .available.opacity(0.16)
        }

        return .unavailable.opacity(0.18)
    }

    private var borderColor: Color {
        if evaluation.isLastContinuousDay {
            return .lastDay
        }

        if isToday {
            return .ink.opacity(0.55)
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
            status = "planned trip day"
        } else if isNextPossibleEntry {
            status = "next possible entry date, available Schengen day"
        } else if evaluation.canBeSchengenDay {
            status = "available Schengen day"
        } else {
            status = "not available"
        }

        return "\(evaluation.date.formatted(date: .complete, time: .omitted)), \(status)"
    }
}

struct LegendView: View {
    var nextPossibleEntryDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Calendar key")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                LegendItem(color: .trip, text: "Filled blue: planned trip")
                LegendItem(color: .available, text: "Green: can enter")
                LegendItem(color: .unavailable, text: "Red: no day left")
                LegendItem(color: .lastDay, text: "Orange ring: latest exit", outlined: true)
                LegendItem(color: .available, text: "Green ring: next entry", outlined: true)
            }

            if let nextPossibleEntryDate = nextPossibleEntryDate {
                Text("Next possible entry: \(nextPossibleEntryDate.formatted(date: .long, time: .omitted))")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LegendItem: View {
    var color: Color
    var text: String
    var outlined = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(outlined ? Color.clear : color.opacity(0.22))
                .overlay(
                    Circle()
                        .stroke(color, lineWidth: outlined ? 2 : 0)
                )
                .frame(width: 12, height: 12)

            Text(text)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}
