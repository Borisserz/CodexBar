import CodexBarCore
import Foundation

enum AntigravityAutoGuidance {
    /// Menu line when Auto keeps a selected account and therefore cannot use an identity-free agy report.
    static let selectedAccountLimitsUnavailable =
        "Limits not available. Auto does not use identity-free agy reports for a selected account. " +
        "Switch Usage source to CLI to show those quotas."

    static func shouldExplainSelectedAccountSkip(
        provider: UsageProvider,
        usageSource: AntigravityUsageDataSource,
        hasSelectedTokenAccount: Bool,
        rateLimitsUnavailable: Bool) -> Bool
    {
        provider == .antigravity &&
            usageSource == .auto &&
            hasSelectedTokenAccount &&
            rateLimitsUnavailable
    }
}
