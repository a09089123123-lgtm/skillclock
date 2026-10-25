import SwiftUI

struct TrainingView: View {
    @ObservedObject var controller: MonitorController
    @State private var enemyName = "训练敌方"
    @State private var spell: SummonerSpell = .flash

    var body: some View {
        Form {
            Section("用途") {
                Text("这里验证倒计时、去重、记录和语音提醒。手动触发不代表程序已经能识别真实技能。")
                    .font(.footnote)
                Text("开启训练素材采集后，每次触发的当前画面会连同标签保存在设备本地，用于后续训练自动识别模型。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("训练素材") {
                Toggle("保存训练素材", isOn: $controller.trainingSampleEnabled)
                Text("已保存 \(controller.trainingSampleCount) 条")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("导出位置：文件 App → 我的 iPhone → 技能时钟 → TrainingSamples")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(controller.trainingSampleDirectoryPath)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
            Section("训练事件") {
                TextField("敌方名称", text: $enemyName)
                Picker("召唤师技能", selection: $spell) {
                    ForEach(SummonerSpell.allCases) { spell in
                        Text(spell.displayName).tag(spell)
                    }
                }
                if controller.isTrainingSession {
                    Button("触发一次训练施法") {
                        controller.simulateTrainingCast(enemyName: enemyName, spell: spell)
                    }
                    Button("结束并保存训练") {
                        controller.finishTraining()
                    }
                } else {
                    Button("开始训练验证") {
                        Task { await controller.startTraining() }
                    }
                }
            }
            Section("当前状态") {
                Text(controller.statusMessage)
                Text("已记录 \(controller.activeTimers.count) 个计时")
            }
        }
        .navigationTitle("训练验证")
    }
}
