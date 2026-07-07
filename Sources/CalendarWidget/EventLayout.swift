import EventKit

/// タイムライン上での横位置(重複予定の列割当)を計算する。
struct PositionedEvent: Identifiable {
    let event: EKEvent
    let column: Int
    let columnCount: Int

    var id: String {
        (event.eventIdentifier ?? event.title ?? "?") + "-\(event.startDate.timeIntervalSince1970)"
    }
}

enum EventLayout {
    /// 時間帯が重なる予定をクラスタにまとめ、クラスタ内で貪欲に列を割り当てる。
    static func layout(_ events: [EKEvent]) -> [PositionedEvent] {
        let sorted = events.sorted {
            $0.startDate != $1.startDate
                ? $0.startDate < $1.startDate
                : $0.endDate > $1.endDate
        }

        var clusters: [[EKEvent]] = []
        var clusterEnd = Date.distantPast
        for event in sorted {
            if !clusters.isEmpty && event.startDate < clusterEnd {
                clusters[clusters.count - 1].append(event)
                clusterEnd = max(clusterEnd, event.endDate)
            } else {
                clusters.append([event])
                clusterEnd = event.endDate
            }
        }

        var result: [PositionedEvent] = []
        for cluster in clusters {
            var columnEnds: [Date] = []
            var assignments: [(EKEvent, Int)] = []
            for event in cluster {
                if let free = columnEnds.firstIndex(where: { $0 <= event.startDate }) {
                    columnEnds[free] = event.endDate
                    assignments.append((event, free))
                } else {
                    columnEnds.append(event.endDate)
                    assignments.append((event, columnEnds.count - 1))
                }
            }
            for (event, column) in assignments {
                result.append(PositionedEvent(event: event, column: column, columnCount: columnEnds.count))
            }
        }
        return result
    }
}
