import SwiftUI

struct DiffView: View {
    let oldText: String
    let newText: String
    @State private var diffLines: [DiffLine] = []

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 0) {
                ForEach(diffLines) { line in
                    DiffLineRow(line: line)
                }
            }
        }
        .onAppear {
            diffLines = LineDiff.compute(old: oldText, new: newText)
        }
    }
}

struct DiffLineRow: View {
    let line: DiffLine

    var body: some View {
        HStack(spacing: 0) {
            Text(prefix)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(prefixColor)
                .frame(width: 24)
                .padding(.horizontal, 4)

            Text("\(line.lineNumber)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(minWidth: 36, alignment: .trailing)
                .padding(.horizontal, 4)

            Text(line.content)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
        }
        .background(backgroundColor)
        .frame(minHeight: 22)
    }

    private var prefix: String {
        switch line.type {
        case .added: return "+"
        case .removed: return "-"
        case .unchanged, .modified: return " "
        }
    }

    private var prefixColor: Color {
        switch line.type {
        case .added: return .green
        case .removed: return .red
        case .unchanged, .modified: return .clear
        }
    }

    private var backgroundColor: Color {
        switch line.type {
        case .added: return Color.green.opacity(0.1)
        case .removed: return Color.red.opacity(0.1)
        case .unchanged, .modified: return Color.clear
        }
    }
}

struct DiffSummaryView: View {
    let oldText: String
    let newText: String

    private var addedCount: Int {
        let diffs = LineDiff.compute(old: oldText, new: newText)
        return diffs.filter { $0.type == .added }.count
    }

    private var removedCount: Int {
        let diffs = LineDiff.compute(old: oldText, new: newText)
        return diffs.filter { $0.type == .removed }.count
    }

    var body: some View {
        HStack(spacing: 16) {
            Label("\(addedCount) added", systemImage: "plus.circle.fill")
                .foregroundStyle(.green)
            Label("\(removedCount) removed", systemImage: "minus.circle.fill")
                .foregroundStyle(.red)
        }
        .font(.caption)
    }
}
