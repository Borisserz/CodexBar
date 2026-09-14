import CodexBarCore
import Foundation

enum AntigravityAutoGuidance {
    /// Menu line when Auto keeps a selected or injected account and therefore cannot use an identity-free agy report.
    static let selectedAccountLimitsUnavailable =
        "Limits not available. Auto does not use identity-free agy reports for a selected or injected account. " +
        "Switch Usage source to CLI to show those quotas."

    static func shouldExplainSelectedAccountSkip(
        provider: UsageProvider,
        usageSource: AntigravityUsageDataSource,
        hasSelectedTokenAccount: Bool,
        hasInjectedOAuthCredentials: Bool,
        rateLimitsUnavailable: Bool) -> Bool
    {
        provider == .antigravity &&
            usageSource == .auto &&
            (hasSelectedTokenAccount || hasInjectedOAuthCredentials) &&
            rateLimitsUnavailable
    }

    static func hasInjectedOAuthCredentials(in environment: [String: String]) -> Bool {
        environment[AntigravityOAuthCredentialsStore.environmentCredentialsKey] != nil
    }
}
