import Foundation

enum SyntaxLanguage: String, CaseIterable, Identifiable {
    case swift
    case python
    case javascript
    case typescript
    case json
    case yaml
    case markdown
    case html
    case css
    case c
    case cpp
    case rust
    case go
    case shell
    case dart
    case java
    case kotlin
    case plain

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .json: return "JSON"
        case .yaml: return "YAML"
        case .markdown: return "Markdown"
        case .html: return "HTML"
        case .css: return "CSS"
        case .c: return "C"
        case .cpp: return "C++"
        case .rust: return "Rust"
        case .go: return "Go"
        case .shell: return "Shell"
        case .dart: return "Dart"
        case .java: return "Java"
        case .kotlin: return "Kotlin"
        case .plain: return "Plain Text"
        }
    }

    static func detect(from filename: String) -> SyntaxLanguage {
        let ext = filename.lowercased().pathExtension
        switch ext {
        case "swift": return .swift
        case "py", "pyw": return .python
        case "js", "jsx", "mjs": return .javascript
        case "ts", "tsx": return .typescript
        case "json": return .json
        case "yaml", "yml": return .yaml
        case "md", "markdown": return .markdown
        case "html", "htm": return .html
        case "css", "scss", "less": return .css
        case "c", "h": return .c
        case "cpp", "cc", "cxx", "hpp": return .cpp
        case "rs": return .rust
        case "go": return .go
        case "sh", "bash", "zsh": return .shell
        case "dart": return .dart
        case "java": return .java
        case "kt", "kts": return .kotlin
        default: return .plain
        }
    }
}

enum SyntaxToken {
    case keyword(String)
    case string(String)
    case number(String)
    case comment(String)
    case type(String)
    case function(String)
    case operatorToken(String)
    case plain(String)
    case preprocessor(String)
    case markupTag(String)
}

struct SyntaxHighlighter {
    private let language: SyntaxLanguage

    init(language: SyntaxLanguage) {
        self.language = language
    }

    func highlight(_ text: String) -> [(token: SyntaxToken, nsString: NSString)] {
        let lines = text.components(separatedBy: .newlines)
        var result: [(token: SyntaxToken, nsString: NSString)] = []

        for line in lines {
            let tokens = tokenizeLine(line)
            for token in tokens {
                result.append((token: token, nsString: line as NSString))
            }
        }

        return result
    }

    func highlightLine(_ line: String) -> [SyntaxToken] {
        return tokenizeLine(line)
    }

    private func tokenizeLine(_ line: String) -> [SyntaxToken] {
        guard !line.isEmpty else { return [.plain("")] }

        var tokens: [SyntaxToken] = []
        var remaining = line[...]

        while !remaining.isEmpty {
            var matched = false

            for rule in languageRules {
                if let match = rule.match(in: remaining) {
                    tokens.append(rule.token(for: match))
                    remaining = remaining[match.range.upperBound...]
                    matched = true
                    break
                }
            }

            if !matched {
                let char = remaining.removeFirst()
                if let last = tokens.last, case .plain(let text) = token {
                    tokens[tokens.count - 1] = .plain(text + String(char))
                } else {
                    tokens.append(.plain(String(char)))
                }
            }
        }

        return tokens.isEmpty ? [.plain("")] : tokens
    }

    private var languageRules: [HighlightRule] {
        switch language {
        case .swift: return swiftRules
        case .python: return pythonRules
        case .javascript, .typescript: return jsRules
        case .json: return jsonRules
        case .yaml: return yamlRules
        case .markdown: return markdownRules
        case .html: return htmlRules
        case .css: return cssRules
        case .c, .cpp: return cRules
        case .rust: return rustRules
        case .go: return goRules
        case .shell: return shellRules
        case .dart: return dartRules
        case .java: return javaRules
        case .kotlin: return kotlinRules
        case .plain: return []
        }
    }
}

struct HighlightRule {
    let pattern: String
    let tokenType: TokenFactory

    func match(in string: Substring) -> MatchResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = String(string) as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let match = regex.firstMatch(in: String(string), options: .anchored, range: range) else {
            return nil
        }
        return MatchResult(matchedString: nsString.substring(with: match.range), range: match.range)
    }
}

struct MatchResult {
    let matchedString: String
    let range: NSRange
}

enum TokenFactory {
    case keyword
    case string
    case number
    case comment
    case type
    case function
    case operatorToken
    case preprocessor
    case markupTag
}

extension HighlightRule {
    func token(for match: MatchResult) -> SyntaxToken {
        switch tokenType {
        case .keyword: return .keyword(match.matchedString)
        case .string: return .string(match.matchedString)
        case .number: return .number(match.matchedString)
        case .comment: return .comment(match.matchedString)
        case .type: return .type(match.matchedString)
        case .function: return .function(match.matchedString)
        case .operatorToken: return .operatorToken(match.matchedString)
        case .preprocessor: return .preprocessor(match.matchedString)
        case .markupTag: return .markupTag(match.matchedString)
        }
    }
}

// MARK: - Language Rules

extension SyntaxHighlighter {
    private var swiftRules: [HighlightRule] {
        [
            HighlightRule(pattern: #"\/\/.*"#, tokenType: .comment),
            HighlightRule(pattern: #"/\*[\s\S]*?\*/"#, tokenType: .comment),
            HighlightRule(pattern: #""[^"\\]*(\\.[^"\\]*)*""#, tokenType: .string),
            HighlightRule(pattern: #""[^"\\]*(\\.[^"\\]*)*""# , tokenType: .string),
            HighlightRule(pattern: #"\b(import|var|let|func|class|struct|enum|protocol|extension|return|if|else|for|while|repeat|switch|case|default|break|continue|fallthrough|in|as|is|try|catch|throw|throws|async|await|some|any|init|deinit|static|public|private|internal|fileprivate|open|final|override|required|convenience|lazy|weak|unowned|didSet|willSet|typealias|associatedtype|where|guard|defer|subscript|operator|precedencegroup|associatedtype|typealias|indirect|case|associatedvalue|rawValue|mutating|nonmutating|subscript|get|set|willSet|didSet|repeat|from|#available|#if|#elseif|#else|#endif|#warning|#error|true|false|nil|self|Self|super|uchos|cParam)\b"#, tokenType: .keyword),
            HighlightRule(pattern: #"\b(Int|Double|Float|String|Bool|Character|Array|Dictionary|Set|Optional|Result|URL|Date|Data|Error|Void|Never|Any|AnyObject|Codable|Decodable|Encodable|Identifiable|Hashable|Equatable|Comparable|CustomStringConvertible|Sendable|View|ObservableObject|Published|StateObject|EnvironmentObject|State|Binding|Environment|Published)\b"#, tokenType: .type),
            HighlightRule(pattern: #"\b([A-Z][a-zA-Z0-9]*)\b"#, tokenType: .type),
            HighlightRule(pattern: #"\b([a-z][a-zA-Z0-9]*)\s*(?=\()"#, tokenType: .function),
            HighlightRule(pattern: #"\b[0-9]+\.?[0-9]*\b"#, tokenType: .number),
            HighlightRule(pattern: #"[+\-*/%=!<>&|^~?:]+"#, tokenType: .operatorToken),
        ]
    }

    private var pythonRules: [HighlightRule] {
        [
            HighlightRule(pattern: #"#.*"#, tokenType: .comment),
            HighlightRule(pattern: #"""[^"\\]*(\\.[^"\\]*)*"""#, tokenType: .string),
            HighlightRule(pattern: #"'[^'\\]*(\\.[^'\\]*)*'"#, tokenType: .string),
            HighlightRule(pattern: #"f"""[^"\\]*(\\.[^"\\]*)*"""#, tokenType: .string),
            HighlightRule(pattern: #"f'[^'\\]*(\\.[^'\\]*)*'"#, tokenType: .string),
            HighlightRule(pattern: #"\b(def|class|import|from|return|if|elif|else|for|while|break|continue|pass|raise|try|except|finally|with|as|lambda|yield|global|nonlocal|assert|del|in|not|and|or|is|True|False|None|self|async|await|print|range|len|int|str|float|list|dict|set|tuple|bool|type|super|property|staticmethod|classmethod)\b"#, tokenType: .keyword),
            HighlightRule(pattern: #"\b(int|str|float|bool|list|dict|set|tuple|None|True|False|Exception|ValueError|TypeError|KeyError|IndexError|StopIteration|RuntimeError|IOError|OSError|ImportError|ModuleNotFoundError|AttributeError|NameError)\b"#, tokenType: .type),
            HighlightRule(pattern: #"\b([a-z_][a-zA-Z0-9_]*)\s*(?=\()"#, tokenType: .function),
            HighlightRule(pattern: #"\b[0-9]+\.?[0-9]*\b"#, tokenType: .number),
            HighlightRule(pattern: #"[+\-*/%=!<>&|^~@:]+"#, tokenType: .operatorToken),
        ]
    }

    private var jsRules: [HighlightRule] {
        [
            HighlightRule(pattern: #"\/\/.*"#, tokenType: .comment),
            HighlightRule(pattern: #"/\*[\s\S]*?\*/"#, tokenType: .comment),
            HighlightRule(pattern: #"`[^`\\]*(\\.[^`\\]*)*`"#, tokenType: .string),
            HighlightRule(pattern: #""[^"\\]*(\\.[^"\\]*)*""#, tokenType: .string),
            HighlightRule(pattern: #"'[^'\\]*(\\.[^'\\]*)*'"#, tokenType: .string),
            HighlightRule(pattern: #"\b(var|let|const|function|class|extends|return|if|else|for|while|do|switch|case|break|continue|new|delete|typeof|instanceof|in|of|this|super|import|export|default|from|async|await|yield|try|catch|finally|throw|static|get|set|true|false|null|undefined|void|console|require|module|npm)\b"#, tokenType: .keyword),
            HighlightRule(pattern: #"\b(Array|Object|String|Number|Boolean|Map|Set|Promise|Error|RegExp|Date|Math|JSON|Proxy|Reflect|Symbol|WeakMap|WeakSet|Int8Array|Uint8Array|Float32Array|Float64Array)\b"#, tokenType: .type),
            HighlightRule(pattern: #"\b([a-zA-Z_$][a-zA-Z0-9_$]*)\s*(?=\()"#, tokenType: .function),
            HighlightRule(pattern: #"\b[0-9]+\.?[0-9]*\b"#, tokenType: .number),
            HighlightRule(pattern: #"[+\-*/%=!<>&|^~?:]+"#, tokenType: .operatorToken),
        ]
    }

    private var jsonRules: [HighlightRule] {
        [
            HighlightRule(pattern: #""[^"\\]*(\\.[^"\\]*)*"\s*(?=:)"#, tokenType: .keyword),
            HighlightRule(pattern: #""[^"\\]*(\\.[^"\\]*)*""#, tokenType: .string),
            HighlightRule(pattern: #"\b(true|false|null)\b"#, tokenType: .keyword),
            HighlightRule(pattern: #"\b[0-9]+\.?[0-9]*\b"#, tokenType: .number),
        ]
    }

    private var yamlRules: [HighlightRule] {
        [
            HighlightRule(pattern: #"#.*"#, tokenType: .comment),
            HighlightRule(pattern: #""[^"\\]*(\\.[^"\\]*)*""#, tokenType: .string),
            HighlightRule(pattern: #"'[^'\\]*(\\.[^'\\]*)*'"#, tokenType: .string),
            HighlightRule(pattern: #"^[\w.-]+(?=\s*:)"#, tokenType: .keyword),
            HighlightRule(pattern: #"\b(true|false|null|yes|no|on|off)\b"#, tokenType: .keyword),
            HighlightRule(pattern: #"\b[0-9]+\.?[0-9]*\b"#, tokenType: .number),
        ]
    }

    private var markdownRules: [HighlightRule] {
        [
            HighlightRule(pattern: #"^#{1,6}\s.*"#, tokenType: .keyword),
            HighlightRule(pattern: #"\*\*[^*]+\*\*"#, tokenType: .type),
            HighlightRule(pattern: #"\*[^*]+\*"#, tokenType: .function),
            HighlightRule(pattern: #"`[^`]+`"#, tokenType: .string),
            HighlightRule(pattern: #""[^"]+""\([^)]+\)"#, tokenType: .function),
            HighlightRule(pattern: #"^\s*[-*+]\s"#, tokenType: .operatorToken),
            HighlightRule(pattern: #"^\s*\d+\.\s"#, tokenType: .operatorToken),
            HighlightRule(pattern: #"\[([^\]]+)\]\([^)]+\)"#, tokenType: .function),
        ]
    }

    private var htmlRules: [HighlightRule] {
        [
            HighlightRule(pattern: #"<!--[\s\S]*?-->"#, tokenType: .comment),
            HighlightRule(pattern: #"<\/?[a-zA-Z][a-zA-Z0-9]*"#, tokenType: .markupTag),
            HighlightRule(pattern: #">"#, tokenType: .markupTag),
            HighlightRule(pattern: #"\/?>"#, tokenType: .markupTag),
            HighlightRule(pattern: #"[a-zA-Z-]+(=)"#, tokenType: .keyword),
            HighlightRule(pattern: #""[^"]*""#, tokenType: .string),
            HighlightRule(pattern: #"'[^']*'"#, tokenType: .string),
            HighlightRule(pattern: #"\b(html|head|body|div|span|p|a|h[1-6]|ul|ol|li|table|tr|td|th|form|input|button|img|script|style|link|meta|title|section|article|nav|header|footer|main|aside|figure|figcaption|video|audio|source|canvas|svg|path|circle|rect|line|text|g|defs|use)\b"#, tokenType: .type),
        ]
    }

    private var cssRules: [HighlightRule] {
        [
            HighlightRule(pattern: #"\/\*[\s\S]*?\*\/"#, tokenType: .comment),
            HighlightRule(pattern: #"\.[a-zA-Z_-][a-zA-Z0-9_-]*"#, tokenType: .keyword),
            HighlightRule(pattern: #"#[a-zA-Z_-][a-zA-Z0-9_-]*"#, tokenType: .keyword),
            HighlightRule(pattern: #"\b(color|background|margin|padding|border|font|display|position|width|height|top|left|right|bottom|flex|grid|transform|transition|animation|opacity|z-index|overflow|text-align|line-height|letter-spacing|box-shadow|border-radius|background-color|background-image)\b"#, tokenType: .keyword),
            HighlightRule(pattern: #"\b(px|em|rem|%|vh|vw|deg|s|ms)\b"#, tokenType: .number),
            HighlightRule(pattern: #":\s*"#, tokenType: .operatorToken),
            HighlightRule(pattern: #"[a-zA-Z-]+(?=\s*\{)"#, tokenType: .type),
            HighlightRule(pattern: #"#[0-9a-fA-F]{3,8}\b"#, tokenType: .number),
            HighlightRule(pattern: #"\b[0-9]+\.?[0-9]*\b"#, tokenType: .number),
            HighlightRule(pattern: #""[^"]*""#, tokenType: .string),
            HighlightRule(pattern: #"'[^']*'"#, tokenType: .string),
        ]
    }

    private var cRules: [HighlightRule] {
        [
            HighlightRule(pattern: #"\/\/.*"#, tokenType: .comment),
            HighlightRule(pattern: #"/\*[\s\S]*?\*/"#, tokenType: .comment),
            HighlightRule(pattern: #""[^"\\]*(\\.[^"\\]*)*""#, tokenType: .string),
            HighlightRule(pattern: #"'[^'\\]*(\\.[^'\\]*)*'"#, tokenType: .string),
            HighlightRule(pattern: #"#\s*(include|import|define|ifdef|ifndef|endif|if|else|elif|undef|pragma|error|warning)"#, tokenType: .preprocessor),
            HighlightRule(pattern: #"\b(int|long|short|unsigned|signed|char|float|double|void|bool|auto|const|static|extern|register|volatile|struct|union|enum|typedef|sizeof|return|if|else|for|while|do|switch|case|break|continue|goto|default|nullptr|true|false|class|public|private|protected|virtual|override|new|delete|namespace|using|try|catch|throw|template|typename|concept|requires|co_await|co_return|co_yield|constexpr|consteval|constinit|inline|noexcept|static_assert|thread_local|alignas|alignof|decltype|nullptr|static_cast|dynamic_cast|reinterpret_cast|const_cast)\b"#, tokenType: .keyword),
            HighlightRule(pattern: #"\b(int|char|float|double|void|bool|size_t|int8_t|int16_t|int32_t|int64_t|uint8_t|uint16_t|uint32_t|uint64_t)\b"#, tokenType: .type),
            HighlightRule(pattern: #"\b([a-zA-Z_][a-zA-Z0-9_]*)\s*(?=\()"#, tokenType: .function),
            HighlightRule(pattern: #"\b[0-9]+\.?[0-9]*[fFlL]?\b"#, tokenType: .number),
            HighlightRule(pattern: #"[+\-*/%=!<>&|^~?:]+"#, tokenType: .operatorToken),
        ]
    }

    private var rustRules: [HighlightRule] {
        [
            HighlightRule(pattern: #"\/\/.*"#, tokenType: .comment),
            HighlightRule(pattern: #"\/\*[\s\S]*?\*\/"#, tokenType: .comment),
            HighlightRule(pattern: #""[^"\\]*(\\.[^"\\]*)*""#, tokenType: .string),
            HighlightRule(pattern: #"r#"[^"]*"#""#, tokenType: .string),
            HighlightRule(pattern: #"'[a-zA-Z_][a-zA-Z0-9_]*"#, tokenType: .type),
            HighlightRule(pattern: #"\b(fn|let|mut|const|struct|enum|impl|trait|type|pub|use|mod|crate|self|super|return|if|else|for|while|loop|break|continue|match|as|in|ref|move|async|await|dyn|where|unsafe|extern|static|box|move|ref|deref|true|false|Some|None|Ok|Err|Self|self|crate|super|std|vec|println|format|String|Vec|Option|Result|Box|Rc|Arc|Cell|RefCell|HashMap|HashSet|BTreeMap|BTreeSet|Mutex|RwLock|Pin|Future|Stream|Iterator|IntoIterator|Display|Debug|Clone|Copy|Default|PartialEq|Eq|PartialOrd|Ord|Hash|From|Into|TryFrom|TryInto|AsRef|AsMut|Deref|DerefMut|Drop|Fn|FnMut|FnOnce)\b"#, tokenType: .keyword),
            HighlightRule(pattern: #"\b(i8|i16|i32|i64|i128|isize|u8|u16|u32|u64|u128|usize|f32|f64|bool|char|str|String|Vec|Option|Result|Box|Rc|Arc|HashMap|HashSet|BTreeMap|BTreeSet|Self)\b"#, tokenType: .type),
            HighlightRule(pattern: #"\b([a-z_][a-zA-Z0-9_]*)\s*(?=\()"#, tokenType: .function),
            HighlightRule(pattern: #"\b[0-9]+\.?[0-9]*\b"#, tokenType: .number),
            HighlightRule(pattern: #"[+\-*/%=!<>&|^~?@:]+"#, tokenType: .operatorToken),
        ]
    }

    private var goRules: [HighlightRule] {
        [
            HighlightRule(pattern: #"\/\/.*"#, tokenType: .comment),
            HighlightRule(pattern: #"\/\*[\s\S]*?\*\/"#, tokenType: .comment),
            HighlightRule(pattern: #""[^"\\]*(\\.[^"\\]*)*""#, tokenType: .string),
            HighlightRule(pattern: #"`[^`]*`"#, tokenType: .string),
            HighlightRule(pattern: #"'[^'\\]'#, tokenType: .string),
            HighlightRule(pattern: #"\b(package|import|func|var|const|type|struct|interface|map|chan|go|defer|return|if|else|for|range|switch|case|default|break|continue|select|fallthrough|nil|true|false|iota|append|cap|close|complex|copy|delete|imag|len|make|new|panic|print|println|real|recover|error|string|byte|rune|int|int8|int16|int32|int64|uint|uint8|uint16|uint32|uint64|float32|float64|complex64|complex128|bool|any|comparable)\b"#, tokenType: .keyword),
            HighlightRule(pattern: #"\b(string|byte|rune|int|int8|int16|int32|int64|uint|uint8|uint16|uint32|uint64|float32|float64|complex64|complex128|bool|error|any|comparable|fmt|os|io|net|http|json|sync|context|time|math|strings|strconv|filepath)\b"#, tokenType: .type),
            HighlightRule(pattern: #"\b([a-zA-Z_][a-zA-Z0-9_]*)\s*(?=\()"#, tokenType: .function),
            HighlightRule(pattern: #"\b[0-9]+\.?[0-9]*\b"#, tokenType: .number),
            HighlightRule(pattern: #"[+\-*/%=!<>&|^~?:]+"#, tokenType: .operatorToken),
        ]
    }

    private var shellRules: [HighlightRule] {
        [
            HighlightRule(pattern: #"#.*"#, tokenType: .comment),
            HighlightRule(pattern: #""[^"\\]*(\\.[^"\\]*)*""#, tokenType: .string),
            HighlightRule(pattern: #"'[^']*'"#, tokenType: .string),
            HighlightRule(pattern: #"\b(if|then|else|elif|fi|for|while|do|done|case|esac|in|function|return|exit|local|export|source|alias|unalias|set|unset|shift|eval|exec|cd|pwd|echo|printf|read|test|let|select|until|declare|typeset|readonly|declare|trap|wait|kill|bg|fg|jobs|disown|suspend|logout|hash|type|command|builtin|enable|help|times|umask|ulimit|getopts|mapfile|readarray)\b"#, tokenType: .keyword),
            HighlightRule(pattern: #"\b(echo|printf|read|cd|pwd|ls|cp|mv|rm|mkdir|rmdir|touch|chmod|chown|grep|sed|awk|find|xargs|sort|uniq|head|tail|wc|cat|less|more|cut|tr|tee|diff|patch|tar|gzip|gunzip|curl|wget|ssh|scp|rsync|git|make|gcc|g++|clang|python|python3|node|npm|brew|apt|yum|dnf|pacman|apt-get|sudo|su|passwd|whoami|id|date|cal|bc|dc|expr|true|false|yes|seq|sleep|timeout|watch|notify-send)\b"#, tokenType: .type),
            HighlightRule(pattern: #"\$[a-zA-Z_][a-zA-Z0-9_]*"#, tokenType: .function),
            HighlightRule(pattern: #"\$\{[a-zA-Z_][a-zA-Z0-9_]*\}"#, tokenType: .function),
            HighlightRule(pattern: #"\b[0-9]+\b"#, tokenType: .number),
            HighlightRule(pattern: #"[|;&<>(){}$!]+"#, tokenType: .operatorToken),
        ]
    }

    private var dartRules: [HighlightRule] {
        [
            HighlightRule(pattern: #"\/\/.*"#, tokenType: .comment),
            HighlightRule(pattern: #"\/\*[\s\S]*?\*\/"#, tokenType: .comment),
            HighlightRule(pattern: #""[^"\\]*(\\.[^"\\]*)*""#, tokenType: .string),
            HighlightRule(pattern: #"'[^'\\]*(\\.[^'\\]*)*'"#, tokenType: .string),
            HighlightRule(pattern: #"\b(import|export|library|part|class|abstract|extends|implements|with|enum|mixin|typedef|static|final|const|late|var|dynamic|void|int|double|String|bool|List|Map|Set|Function|Future|Stream|Iterable|async|await|yield|return|if|else|for|while|do|switch|case|break|continue|try|catch|finally|throw|new|this|super|true|false|null|required|late|covariant|external|factory|get|set|operator|is|as|in)\b"#, tokenType: .keyword),
            HighlightRule(pattern: #"\b(int|double|String|bool|List|Map|Set|Function|Future|Stream|Iterable|Object|Symbol|Type|void|Null|Never|dynamic|var|const|final)\b"#, tokenType: .type),
            HighlightRule(pattern: #"\b([a-z_][a-zA-Z0-9_]*)\s*(?=\()"#, tokenType: .function),
            HighlightRule(pattern: #"\b[0-9]+\.?[0-9]*\b"#, tokenType: .number),
            HighlightRule(pattern: #"[+\-*/%=!<>&|^~?@:]+"#, tokenType: .operatorToken),
        ]
    }

    private var javaRules: [HighlightRule] {
        [
            HighlightRule(pattern: #"\/\/.*"#, tokenType: .comment),
            HighlightRule(pattern: #"\/\*[\s\S]*?\*\/"#, tokenType: .comment),
            HighlightRule(pattern: #""[^"\\]*(\\.[^"\\]*)*""#, tokenType: .string),
            HighlightRule(pattern: #"'[^'\\]'#, tokenType: .string),
            HighlightRule(pattern: #"\b(import|package|class|interface|enum|extends|implements|abstract|static|final|private|protected|public|void|int|long|short|byte|float|double|char|boolean|String|new|this|super|return|if|else|for|while|do|switch|case|break|continue|try|catch|finally|throw|throws|instanceof|synchronized|volatile|transient|native|strictfp|assert|enum|record|sealed|permits|var|yield|true|false|null|System|out|println|print)\b"#, tokenType: .keyword),
            HighlightRule(pattern: #"\b(String|Integer|Double|Float|Boolean|Character|Byte|Short|Long|Object|Class|System|Exception|RuntimeException|IOException|List|ArrayList|Map|HashMap|Set|HashSet|Queue|LinkedList|TreeMap|TreeSet|Collections|Arrays|Optional|Stream|Predicate|Function|Supplier|Consumer|CompletableFuture)\b"#, tokenType: .type),
            HighlightRule(pattern: #"\b([a-z_][a-zA-Z0-9_]*)\s*(?=\()"#, tokenType: .function),
            HighlightRule(pattern: #"\b[0-9]+\.?[0-9]*[fFdDlL]?\b"#, tokenType: .number),
            HighlightRule(pattern: #"[+\-*/%=!<>&|^~?:]+"#, tokenType: .operatorToken),
        ]
    }

    private var kotlinRules: [HighlightRule] {
        [
            HighlightRule(pattern: #"\/\/.*"#, tokenType: .comment),
            HighlightRule(pattern: #"\/\*[\s\S]*?\*\/"#, tokenType: .comment),
            HighlightRule(pattern: #""[^"\\]*(\\.[^"\\]*)*""#, tokenType: .string),
            HighlightRule(pattern: #"'[^'\\]'#, tokenType: .string),
            HighlightRule(pattern: #"\b(package|import|class|interface|object|enum|data|sealed|abstract|open|final|internal|private|protected|public|override|fun|val|var|typealias|constructor|init|companion|by|lazy|lateinit|vararg|crossinline|noinline|reified|out|in|where|return|if|else|for|while|do|when|try|catch|finally|throw|is|as|in|not|true|false|null|this|super|it|also|apply|let|run|with|takeIf|takeUnless|use|to|until|downTo|step|repeat|println|print|listOf|mapOf|setOf|arrayOf|intArrayOf|longArrayOf|doubleArrayOf|booleanArrayOf|mutableListOf|mutableMapOf|mutableSetOf|emptyList|emptyMap|emptySet|hashMapOf|linkedMapOf|sortedMapOf|hashSetOf|linkedSetOf|sortedSetOf|sequenceOf|generateSequence|buildList|buildMap|buildSet)\b"#, tokenType: .keyword),
            HighlightRule(pattern: #"\b(String|Int|Long|Short|Byte|Float|Double|Boolean|Char|Any|Nothing|Unit|List|MutableList|Map|MutableMap|Set|MutableSet|Array|Pair|Triple|Sequence|Iterable|Collection)\b"#, tokenType: .type),
            HighlightRule(pattern: #"\b([a-z_][a-zA-Z0-9_]*)\s*(?=\()"#, tokenType: .function),
            HighlightRule(pattern: #"\b[0-9]+\.?[0-9]*[fFlL]?\b"#, tokenType: .number),
            HighlightRule(pattern: #"[+\-*/%=!<>&|^~?:@.]+"#, tokenType: .operatorToken),
        ]
    }
}
