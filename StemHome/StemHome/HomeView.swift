import SwiftUI
import UIKit

struct HomeView: View {

    let devices: [Device]
    let activeCount: Int
    let onToggle: (Device) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                    .padding(.horizontal, 16)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(devices) { device in
                        DeviceTile(device: device) {
                            hapticTap()
                            onToggle(device)
                        }
                    }
                }
                .padding(.horizontal, 16)

                if devices.isEmpty {
                    emptyState
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("Home")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(activeCount) active")
                .font(.largeTitle.bold())
            Text(devices.isEmpty
                 ? "Loading devices…"
                 : "\(devices.count) devices · tap a tile to toggle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        Text("No devices yet.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func hapticTap() {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
    }
}

private struct DeviceTile: View {
    let device: Device
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: device.icon)
                        .font(.title2)
                        .foregroundStyle(device.on ? Color.accentColor : .secondary)
                        .frame(width: 28, height: 28)
                    Spacer()
                    Circle()
                        .fill(device.on ? Color.green : Color.gray.opacity(0.35))
                        .frame(width: 10, height: 10)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(device.room)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(device.on ? "On" : "Off")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(device.on ? .green : .secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(device.on ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
