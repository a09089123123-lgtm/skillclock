import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: MonitorController

    var body: some View {
        Form {
            Section("语音") {
                Toggle("技能就绪时再提醒一次", isOn: $controller.settings.speaksReady)
            }
            Section("临近就绪提醒提前量") {
                ForEach(SummonerSpell.allCases) { spell in
                    Stepper(value: leadTimeBinding(for: spell), in: 1...60, step: 1) {
                        HStack {
                            Text(spell.displayName)
                            Spacer()
                            Text("\(Int(controller.settings.leadTime(for: spell, cooldown: controller.cooldownTable.cooldown(for: spell)))) 秒")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section {
                ForEach(SummonerSpell.allCases) { spell in
                    cooldownRow(for: spell)
                }
                Button("全部恢复内置数值", role: .destructive) {
                    controller.resetCooldownOverrides()
                }
            } header: {
                Text("冷却时长校准")
            } footer: {
                Text("当前数值来源：\(controller.cooldownTable.sourceDescription)。内置数值取自第三方资料（未核验），请按你当前的游戏版本校准；校准结果保存在本机。")
            }
        }
        .navigationTitle("提醒设置")
    }

    private func leadTimeBinding(for spell: SummonerSpell) -> Binding<Double> {
        Binding(
            get: { controller.settings.leadTime(for: spell, cooldown: controller.cooldownTable.cooldown(for: spell)) },
            set: { controller.settings.leadTimes[spell.rawValue] = $0 }
        )
    }

    @ViewBuilder
    private func cooldownRow(for spell: SummonerSpell) -> some View {
        let current = controller.cooldownTable.cooldown(for: spell)
        let overridden = controller.cooldownTable.isOverridden(spell)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(spell.displayName)
                Spacer()
                Text("\(Int(current)) 秒")
                    .foregroundStyle(overridden ? Color.accentColor : Color.secondary)
                if overridden {
                    Button("恢复") {
                        controller.updateCooldownOverride(nil, for: spell)
                    }
                    .font(.footnote)
                }
            }
            Stepper(
                value: Binding(
                    get: { current },
                    set: { controller.updateCooldownOverride($0, for: spell) }
                ),
                in: 5...600,
                step: 5
            ) {
                Text("调整 \(spell.displayName) 冷却时长")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
