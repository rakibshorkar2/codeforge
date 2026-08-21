import Foundation

struct DiffLine: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let content: String
    let type: DiffLineType

    enum DiffLineType {
        case added
        case removed
        case unchanged
        case modified
    }
}

struct LineDiff {
    static func compute(old: String, new: String) -> [DiffLine] {
        let oldLines = old.components(separatedBy: .newlines)
        let newLines = new.components(separatedBy: .newlines)

        let lcs = longestCommonSubsequence(oldLines, newLines)

        var result: [DiffLine] = []
        var oldIndex = 0
        var newIndex = 0
        var lineNum = 1

        for lcsLine in lcs {
            while oldIndex < oldLines.count && oldLines[oldIndex] != lcsLine {
                result.append(DiffLine(lineNumber: lineNum, content: oldLines[oldIndex], type: .removed))
                oldIndex += 1
                lineNum += 1
            }
            while newIndex < newLines.count && newLines[newIndex] != lcsLine {
                result.append(DiffLine(lineNumber: lineNum, content: newLines[newIndex], type: .added))
                newIndex += 1
                lineNum += 1
            }
            if oldIndex < oldLines.count && newIndex < newLines.count {
                result.append(DiffLine(lineNumber: lineNum, content: lcsLine, type: .unchanged))
                oldIndex += 1
                newIndex += 1
                lineNum += 1
            }
        }

        while oldIndex < oldLines.count {
            result.append(DiffLine(lineNumber: lineNum, content: oldLines[oldIndex], type: .removed))
            oldIndex += 1
            lineNum += 1
        }
        while newIndex < newLines.count {
            result.append(DiffLine(lineNumber: lineNum, content: newLines[newIndex], type: .added))
            newIndex += 1
            lineNum += 1
        }

        return result
    }

    private static func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [String] {
        let m = a.count
        let n = b.count
        var dp = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 1...m {
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        var result: [String] = []
        var i = m, j = n
        while i > 0 && j > 0 {
            if a[i - 1] == b[j - 1] {
                result.append(a[i - 1])
                i -= 1
                j -= 1
            } else if dp[i - 1][j] > dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }

        return result.reversed()
    }
}
