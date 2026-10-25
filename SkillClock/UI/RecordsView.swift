import SwiftUI

struct RecordsView: View {
    @ObservedObject var controller: MonitorController

    var body: some View {
        List {
            if controller.records.isEmpty {
                Text("暂无对局记录")
                    .foregroundStyle(.secondary)
            }
            ForEach(controller.records) { record in
                Section(record.startedAt.formatted(date: .abbreviated, time: .shortened)) {
                    Text(record.isTraining ? "训练验证" : "对局")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if record.events.isEmpty {
                        Text("没有已确认的技能事件")
                    } else {
                        ForEach(record.events) { event in
                            VStack(alignment: .leading) {
                                Text("\(event.enemyDisplayName) · \(event.spell.displayName)")
                                Text(event.castAt.formatted(date: .omitted, time: .standard))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("对局记录")
        .toolbar {
            Button("清空", role: .destructive, action: controller.clearRecords)
                .disabled(controller.records.isEmpty)
        }
    }
}
