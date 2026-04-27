import SwiftUI

struct MetricCard: View {
    let metric: DashboardMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: metric.icon)
                .font(.title3)
                .foregroundStyle(metric.color)

            Text(metric.value)
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text(metric.title)
                .font(.subheadline.weight(.semibold))

            Text(metric.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct HighlightCard: View {
    let item: DashboardHighlight

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(item.color.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: item.icon)
                        .foregroundStyle(item.color)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Text(item.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct StatusBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }
}

struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

struct DetailHero: View {
    let title: String
    let subtitle: String
    let color: Color
    let systemImage: String

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(color.opacity(0.18))
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.title)
                        .foregroundStyle(color)
                }
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title2.bold())
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
