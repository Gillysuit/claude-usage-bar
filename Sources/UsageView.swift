import SwiftUI

struct UsageView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Claude usage").font(.headline)
                    if let renewal = store.profile?.nextRenewal {
                        Text(renewalText(renewal))
                            .font(.caption).foregroundStyle(.secondary)
                            .help("Estimated from when your subscription started, assuming monthly billing")
                    }
                }
                Spacer()
                if let plan = store.plan {
                    Text(plan.capitalized)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }

            if let error = store.error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            if let notice = store.notice {
                Label(notice, systemImage: "clock").font(.caption).foregroundStyle(.secondary)
            }

            if let usage = store.usage {
                ForEach(usage.allLimits) { LimitRow(limit: $0) }

                if let rows = usage.sevenDayBreakdown?.rows, !rows.isEmpty {
                    Divider()
                    Text("This week by surface").font(.caption).foregroundStyle(.secondary)
                    ForEach(rows.sorted { $0.percent > $1.percent }, id: \.displayName) { row in
                        HStack {
                            Text(row.displayName)
                            Spacer()
                            Text("\(Int(row.percent))%").monospacedDigit().foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                }

                if let spend = usage.spend { SpendRow(spend: spend) }
            } else if store.error == nil && store.notice == nil {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity)
            }

            Divider()
            HStack {
                if let updated = store.updatedAt {
                    Text("Updated \(shortTime(updated))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                // Re-evaluated every few seconds so the button re-enables when the cooldown ends.
                TimelineView(.periodic(from: .now, by: 5)) { context in
                    let next = store.nextAllowedFetch.flatMap { $0 > context.date ? $0 : nil }
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        if store.isLoading { ProgressView().controlSize(.mini) } else { Image(systemName: "arrow.clockwise") }
                    }
                    .buttonStyle(.borderless)
                    .disabled(next != nil)
                    .help(next.map { "Can refresh again after \(shortTime($0))" } ?? "Refresh")
                }
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .padding(.leading, 8)
            }
        }
        .padding(12)
        .frame(width: 280)
    }
}

private struct LimitRow: View {
    let limit: UsageLimit
    private var level: UsageLevel { UsageLevel(limit.percent) }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(limit.title).font(.callout.weight(.medium))
                Spacer()
                Text("\(Int(limit.percent.rounded()))%").font(.callout).monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(nsColor: level.colors.0), Color(nsColor: level.colors.1)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * min(max(limit.percent, 0), 100) / 100)
                }
            }
            .frame(height: 6)
            if let reset = resetText(limit.resetDate) {
                Text(reset).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct SpendRow: View {
    let spend: UsageResponse.Spend

    var body: some View {
        let used = spend.used?.value ?? 0
        let limit = spend.limit?.value
        let status = spend.enabled == true
            ? "on"
            : "off" + (spend.disabledReason.map { " (\($0.replacingOccurrences(of: "_", with: " ")))" } ?? "")
        Divider()
        HStack {
            Text("Extra usage")
            Spacer()
            Text(limit.map { String(format: "$%.2f / $%.2f", used, $0) } ?? String(format: "$%.2f", used))
                .monospacedDigit()
        }
        .font(.callout)
        Text("Extra usage is \(status)").font(.caption).foregroundStyle(.secondary)
    }
}
