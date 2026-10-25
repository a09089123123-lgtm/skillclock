import SwiftUI

struct RootView: View {
    @ObservedObject var controller: MonitorController

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                List {
                    Section("持续监测") {
                        Label(controller.statusMessage, systemImage: statusIcon)
                            .foregroundStyle(statusColor)
                        Text("对局阶段：\(phaseName)")
                        if controller.isTrainingSession {
                            Text("训练验证进行中，可在“训练验证”页面触发测试事件")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            NavigationLink("前往训练验证") {
                                TrainingView(controller: controller)
                            }
                        } else if controller.isSessionActive {
                            Button("停止监测", role: .destructive) {
                                Task { await controller.stopMonitoring() }
                            }
                        } else {
                            Button("开启持续监测") {
                                controller.startMonitoring()
                            }
                        }
                    }

                    Section("敌方技能") {
                        if controller.activeTimers.isEmpty {
                            Text("尚无已确认的冷却计时")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(controller.activeTimers) { timer in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(timer.enemyDisplayName)
                                        Text(timer.spell.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(remainingText(timer.remaining(at: context.date)))
                                        .monospacedDigit()
                                }
                            }
                        }
                    }

                    Section("识别状态") {
                        Text(controller.spellRecognitionStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("冷却数值来源：\(controller.cooldownTable.sourceDescription)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("冷却表为第三方未核验资料，正式使用前必须按当前游戏版本校准。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        NavigationLink("训练验证") {
                            TrainingView(controller: controller)
                        }
                        NavigationLink("提醒设置") {
                            SettingsView(controller: controller)
                        }
                        NavigationLink("对局记录") {
                            RecordsView(controller: controller)
                        }
                    }
                }
            }
            .navigationTitle("技能时钟")
        }
    }

    private var phaseName: String {
        switch controller.phase {
        case .idle: "等待对局"
        case .loading: "加载中"
        case .inMatch: "对局中"
        case .settlement: "结算中"
        case .interrupted: "已中断"
        }
    }

    private var statusIcon: String {
        switch controller.captureState {
        case .capturing: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        default: "dot.radiowaves.left.and.right"
        }
    }

    private var statusColor: Color {
        switch controller.captureState {
        case .capturing: .green
        case .failed: .orange
        default: .primary
        }
    }

    private func remainingText(_ seconds: TimeInterval) -> String {
        seconds <= 0 ? "已就绪" : "\(Int(seconds.rounded(.up))) 秒"
    }
}
