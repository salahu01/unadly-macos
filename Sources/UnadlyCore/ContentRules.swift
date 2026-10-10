import Foundation

/// Builds WebKit content-blocker rule lists (the JSON format used by Safari content
/// blockers and `WKContentRuleListStore`).
public enum ContentRules {
    /// WebKit compiles large lists more reliably in chunks; several lists can be active at once.
    public static let maxRulesPerList = 25_000

    /// CSS selectors for ad slots that stay empty after their requests are blocked.
    public static let hiddenSelectors = [
        #"[id^="google_ads"]"#, #"[id^="div-gpt-ad"]"#, #"[class*="adsbygoogle"]"#, "ins.adsbygoogle",
        #"iframe[src*="doubleclick"]"#, #"iframe[src*="googlesyndication"]"#, "[data-ad-slot]", "[data-ad-unit]",
        ".ad-container", ".ad-slot", ".ad-banner", ".advert", ".advertisement", #"[aria-label="Advertisement"]"#,
    ]

    /// One rule per host: block requests to the host and its subdomains when they're
    /// third-party, so visiting an ad company's own site directly still works.
    public static func blockingRules(for hosts: [String]) throws -> String {
        let rules = hosts.map { host -> Rule in
            let escaped = NSRegularExpression.escapedPattern(for: host)
            return Rule(
                trigger: .init(urlFilter: #"^[a-z]+://([^/:]+\.)?"# + escaped + "[:/]", loadType: ["third-party"]),
                action: .init(type: "block")
            )
        }
        return try encode(rules)
    }

    public static func cosmeticRules() throws -> String {
        try encode([Rule(
            trigger: .init(urlFilter: ".*"),
            action: .init(type: "css-display-none", selector: hiddenSelectors.joined(separator: ", "))
        )])
    }

    /// Splits `hosts` into chunks that each fit in one rule list.
    public static func chunks(of hosts: [String]) -> [[String]] {
        stride(from: 0, to: hosts.count, by: maxRulesPerList).map {
            Array(hosts[$0..<min($0 + maxRulesPerList, hosts.count)])
        }
    }

    private struct Rule: Encodable {
        struct Trigger: Encodable {
            var urlFilter: String
            var loadType: [String]?
            enum CodingKeys: String, CodingKey {
                case urlFilter = "url-filter"
                case loadType = "load-type"
            }
        }
        struct Action: Encodable {
            var type: String
            var selector: String?
        }
        var trigger: Trigger
        var action: Action
    }

    private static func encode(_ rules: [Rule]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return String(decoding: try encoder.encode(rules), as: UTF8.self)
    }
}
