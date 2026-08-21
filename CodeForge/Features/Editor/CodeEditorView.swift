import SwiftUI

struct CodeEditorView: View {
    let tab: EditorTab
    @Binding var content: String
    @State private var lineNumberWidth: CGFloat = 40
    @State private var showSearch = false
    @State private var showGoToLine = false
    @State private var searchText = ""
    @State private var replaceText = ""
    @State private var replaceMode = false
    @State private var goToLineNumber = ""
    @State private var matchCount = 0
    @State private var currentMatch = 0
    @EnvironmentObject var appEnvironment: AppEnvironment

    private let highlighter: SyntaxHighlighter

    init(tab: EditorTab, content: Binding<String>) {
        self.tab = tab
        self._content = content
        self.highlighter = SyntaxHighlighter(language: tab.language)
    }

    var body: some View {
        VStack(spacing: 0) {
            editorToolbar
            Divider()
            HStack(spacing: 0) {
                lineNumbers
                Divider()
                textEditor
            }
        }
        .sheet(isPresented: $showSearch) {
            SearchReplaceView(
                searchText: $searchText,
                replaceText: $replaceText,
                replaceMode: $replaceMode,
                matchCount: $matchCount,
                currentMatch: $currentMatch,
                onSearch: performSearch,
                onNextMatch: nextMatch,
                onPreviousMatch: previousMatch,
                onReplace: replaceCurrent,
                onReplaceAll: replaceAll,
                onDismiss: { showSearch = false }
            )
        }
        .sheet(isPresented: $showGoToLine) {
            GoToLineView(
                lineNumber: $goToLineNumber,
                totalLines: content.components(separatedBy: .newlines).count,
                onGoTo: { line in
                    showGoToLine = false
                },
                onDismiss: { showGoToLine = false }
            )
        }
    }

    private var editorToolbar: some View {
        HStack(spacing: 12) {
            Text(tab.filename)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            if tab.isModified {
                Circle()
                    .fill(.orange)
                    .frame(width: 8, height: 8)
            }

            Spacer()

            Text(tab.language.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))

            Button {
                showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
            }

            Button {
                showGoToLine = true
            } label: {
                Image(systemName: "arrow.right.to.line")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var lineNumbers: some View {
        let lines = content.components(separatedBy: .newlines)
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
                    Text("\(index + 1)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(minWidth: lineNumberWidth, alignment: .trailing)
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                }
            }
        }
        .background(Color(.systemBackground))
        .disabled(true)
    }

    private var textEditor: some View {
        TextEditor(text: $content)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
    }

    private func performSearch() {
    }

    private func nextMatch() {
    }

    private func previousMatch() {
    }

    private func replaceCurrent() {
    }

    private func replaceAll() {
    }
}

struct SearchReplaceView: View {
    @Binding var searchText: String
    @Binding var replaceText: String
    @Binding var replaceMode: Bool
    @Binding var matchCount: Int
    @Binding var currentMatch: Int
    var onSearch: () -> Void
    var onNextMatch: () -> Void
    var onPreviousMatch: () -> Void
    var onReplace: () -> Void
    var onReplaceAll: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Search") {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: searchText) { _, _ in
                                onSearch()
                            }
                    }

                    if !searchText.isEmpty {
                        HStack {
                            Text("\(matchCount) matches")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                onPreviousMatch()
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .disabled(matchCount == 0)
                            Text("\(currentMatch)/\(matchCount)")
                                .font(.caption.monospacedDigit())
                            Button {
                                onNextMatch()
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .disabled(matchCount == 0)
                        }
                    }
                }

                Section("Replace") {
                    Toggle("Replace mode", isOn: $replaceMode)
                    if replaceMode {
                        HStack {
                            Image(systemName: "arrow.right.arrow.left")
                                .foregroundStyle(.secondary)
                            TextField("Replace", text: $replaceText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        HStack {
                            Button("Replace") {
                                onReplace()
                            }
                            .disabled(matchCount == 0 || replaceText.isEmpty)

                            Button("Replace All") {
                                onReplaceAll()
                            }
                            .disabled(matchCount == 0 || replaceText.isEmpty)
                        }
                    }
                }
            }
            .navigationTitle("Search & Replace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct GoToLineView: View {
    @Binding var lineNumber: String
    let totalLines: Int
    var onGoTo: (Int) -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Line number (1-\(totalLines))", text: $lineNumber)
                        .keyboardType(.numberPad)
                        .autocorrectionDisabled()
                } header: {
                    Text("Go to line")
                } footer: {
                    if let line = Int(lineNumber), line >= 1 && line <= totalLines {
                        Text("Line \(line) of \(totalLines)")
                            .foregroundStyle(.secondary)
                    } else if !lineNumber.isEmpty {
                        Text("Enter a number between 1 and \(totalLines)")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Go to Line")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Go") {
                        if let line = Int(lineNumber), line >= 1 && line <= totalLines {
                            onGoTo(line)
                        }
                    }
                    .disabled(Int(lineNumber) == nil || Int(lineNumber)! < 1 || Int(lineNumber)! > totalLines)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
