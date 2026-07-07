import SwiftUI
import EventKit

struct WidgetView: View {
    @ObservedObject var service: CalendarService

    var body: some View {
        Group {
            switch service.authState {
            case .authorized:
                content
            case .denied:
                PermissionView()
            case .undetermined:
                Text("カレンダーへのアクセスを確認中…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var content: some View {
        VStack(spacing: 0) {
            if !service.allDayEvents.isEmpty {
                AllDayBar(events: Array(service.allDayEvents.prefix(2)))
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
            }
            TimelineBody(service: service)
                .padding(8)
        }
    }
}

/// 終日予定のバー(最大2件)
private struct AllDayBar: View {
    let events: [EKEvent]

    var body: some View {
        VStack(spacing: 3) {
            ForEach(events, id: \.self) { event in
                HStack(spacing: 5) {
                    Capsule()
                        .fill(color(for: event))
                        .frame(width: 3, height: 10)
                    Text(event.title ?? "(無題)")
                        .font(.caption2)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("終日")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color(for: event).opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
            }
        }
    }
}

/// タイムライン本体
private struct TimelineBody: View {
    @ObservedObject var service: CalendarService

    private let gutterWidth: CGFloat = 40

    private var windowStart: Date { service.now.addingTimeInterval(-CalendarService.windowBefore) }

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            ZStack(alignment: .topLeading) {
                gridLines(height: height, width: geo.size.width)
                eventBlocks(height: height, width: geo.size.width)
                nowLine(height: height, width: geo.size.width)
            }
        }
        .clipped()
    }

    private func yPosition(_ date: Date, height: CGFloat) -> CGFloat {
        CGFloat(date.timeIntervalSince(windowStart) / CalendarService.windowLength) * height
    }

    // MARK: 罫線と時刻ラベル

    private func gridLines(height: CGFloat, width: CGFloat) -> some View {
        let marks = halfHourMarks()
        return ForEach(marks, id: \.self) { date in
            let y = yPosition(date, height: height)
            let isHour = Calendar.current.component(.minute, from: date) == 0
            HStack(spacing: 4) {
                Text(Self.timeFormatter.string(from: date))
                    .font(.system(size: 9, weight: isHour ? .medium : .regular))
                    .foregroundStyle(isHour ? .secondary : .tertiary)
                    .frame(width: gutterWidth - 8, alignment: .trailing)
                Rectangle()
                    .fill(.primary.opacity(isHour ? 0.18 : 0.08))
                    .frame(height: 1)
            }
            .offset(y: y - 5)
        }
    }

    private func halfHourMarks() -> [Date] {
        let calendar = Calendar.current
        let start = windowStart
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: start)
        var floored = comps
        floored.minute = (comps.minute ?? 0) < 30 ? 0 : 30
        floored.second = 0
        guard var mark = calendar.date(from: floored) else { return [] }
        if mark < start { mark.addTimeInterval(30 * 60) }

        var marks: [Date] = []
        let end = start.addingTimeInterval(CalendarService.windowLength)
        while mark <= end {
            marks.append(mark)
            mark.addTimeInterval(30 * 60)
        }
        return marks
    }

    // MARK: イベント

    private func eventBlocks(height: CGFloat, width: CGFloat) -> some View {
        let areaX = gutterWidth
        let areaWidth = max(width - gutterWidth - 2, 10)
        let windowEnd = windowStart.addingTimeInterval(CalendarService.windowLength)
        let visible = service.timedEvents.filter {
            $0.endDate > windowStart && $0.startDate < windowEnd
        }
        let positioned = EventLayout.layout(visible)

        return ForEach(positioned) { item in
            let start = max(item.event.startDate, windowStart)
            let end = min(item.event.endDate, windowEnd)
            let y = yPosition(start, height: height)
            let blockHeight = max(yPosition(end, height: height) - y, 14)
            let columnWidth = areaWidth / CGFloat(item.columnCount)
            let x = areaX + columnWidth * CGFloat(item.column)

            EventBlock(event: item.event, now: service.now)
                .frame(width: columnWidth - 2, height: blockHeight)
                .offset(x: x, y: y)
        }
    }

    private func nowLine(height: CGFloat, width: CGFloat) -> some View {
        let y = yPosition(service.now, height: height)
        return HStack(spacing: 3) {
            Text(Self.timeFormatter.string(from: service.now))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.red)
                .frame(width: gutterWidth - 8, alignment: .trailing)
            Circle()
                .fill(.red)
                .frame(width: 5, height: 5)
            Rectangle()
                .fill(.red)
                .frame(height: 1.5)
        }
        .offset(y: y - 5)
    }

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "H:mm"
        return f
    }()
}

/// 個々の予定ブロック
private struct EventBlock: View {
    let event: EKEvent
    let now: Date

    private var isPast: Bool { event.endDate <= now }
    private var isCurrent: Bool { event.startDate <= now && now < event.endDate }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color(for: event))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title ?? "(無題)")
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(2)
                Text(TimelineBody.timeFormatter.string(from: event.startDate))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            Spacer(minLength: 0)
        }
        .padding(3)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(color(for: event).opacity(isPast ? 0.10 : 0.22), in: RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(color(for: event).opacity(isCurrent ? 0.9 : 0), lineWidth: 1.5)
        )
        .opacity(isPast ? 0.55 : 1)
        .clipped()
    }
}

/// 権限未許可時の案内
private struct PermissionView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("カレンダーへのアクセスが\n許可されていません")
                .font(.caption)
                .multilineTextAlignment(.center)
            Button("システム設定を開く") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private func color(for event: EKEvent) -> Color {
    if let cgColor = event.calendar?.cgColor {
        return Color(cgColor: cgColor)
    }
    return .accentColor
}
