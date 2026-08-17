import AppKit
import SwiftUI

struct MenuPopover: View {
    @ObservedObject var central: HeartRateCentral

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Heart Rate Menu")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(central.statusText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(central.isFresh ? .green : .secondary)
            }
            .padding(.bottom, 10)

            Divider()

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(central.isFresh ? .green : .secondary)
                Text(central.displayHeartRate)
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(central.isFresh ? .primary : .secondary)
                Text("bpm")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 16)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("心率设备")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        if central.hasRememberedDevice {
                            Text("已绑定设备会在下次扫描时自动重连")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if central.hasRememberedDevice {
                        Button {
                            central.forgetDevice()
                        } label: {
                            Image(systemName: "link.badge.minus")
                        }
                        .buttonStyle(.borderless)
                        .help("解除已绑定设备")
                        .accessibilityLabel("解除已绑定设备")
                    }
                }
                devicePicker
            }
            .padding(.vertical, 11)

            Divider()

            HStack {
                Button {
                    central.scanAgain()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("重新扫描设备")
                Spacer()
                Button("退出") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless)
            }
            .padding(.top, 9)
        }
        .frame(width: 320)
        .padding(12)
    }

    @ViewBuilder
    private var devicePicker: some View {
        if central.devices.isEmpty {
            Text("未发现设备。请确认设备已开启心率广播，然后重新扫描。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Picker("设备", selection: Binding(
                get: { central.selectedDeviceID },
                set: { if let identifier = $0 { central.selectDevice(identifier) } }
            )) {
                Text("选择设备").tag(UUID?.none)
                ForEach(central.devices) { device in
                    Text(device.name).tag(Optional(device.id))
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
    }
}
