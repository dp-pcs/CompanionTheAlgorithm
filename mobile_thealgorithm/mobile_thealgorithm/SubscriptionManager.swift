import Foundation
import Combine
import UIKit

class SubscriptionManager: ObservableObject {
    @Published var showPaywall = false
    @Published var subscriptionError: SubscriptionError?
    @Published var planTier: String = "free"
    @Published var trialDaysRemaining: Int?
    @Published var showTrialBanner = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Listen for subscription errors from API calls
        NotificationCenter.default.publisher(for: .subscriptionRequired)
            .sink { [weak self] notification in
                if let error = notification.object as? SubscriptionError {
                    self?.handleSubscriptionRequired(error)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Check user's subscription status after login
    func checkSubscriptionStatus(apiClient: APIClient) {
        apiClient.fetchAPIKeyStatus { [weak self] result in
            switch result {
            case .success(let status):
                self?.planTier = status.planTier
                
                // Show trial banner if user is on free tier
                if status.planTier == "free" {
                    self?.showTrialBanner = true
                    // Could fetch trial end date from backend to calculate days remaining
                }
                
#if DEBUG
                print("💎 [Subscription] Plan tier: \(status.planTier)")
                if status.usingSystemKeys {
                    print("   ↳ Using system LLM keys")
                } else if status.needsOwnKeys {
                    print("   ↳ Needs own LLM keys")
                }
#endif
                
            case .failure(let error):
#if DEBUG
                print("⚠️ [Subscription] Failed to check status: \(error)")
#endif
            }
        }
    }
    
    /// Called when a 402 error is received
    private func handleSubscriptionRequired(_ error: SubscriptionError) {
#if DEBUG
        print("🔒 [Subscription] Trial/subscription expired")
        print("   ↳ Status: \(error.subscriptionStatus ?? "unknown")")
        if let days = error.daysExpired {
            print("   ↳ Expired \(days) day(s) ago")
        }
#endif
        
        DispatchQueue.main.async {
            self.subscriptionError = error
            self.showPaywall = true
        }
    }
    
    /// Open pricing page in Safari
    func openPricingPage() {
        let urlString = "https://thealgorithm.live\(subscriptionError?.upgradeUrl ?? "/pricing")"
        if let url = URL(string: urlString) {
#if DEBUG
            print("🌐 [Subscription] Opening pricing page: \(url.absoluteString)")
#endif
            UIApplication.shared.open(url)
        }
    }
    
    /// Dismiss the paywall and check status again
    func dismissPaywallAndRefresh(apiClient: APIClient) {
        showPaywall = false
        subscriptionError = nil
        
        // Wait a moment for backend to sync, then check status
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkSubscriptionStatus(apiClient: apiClient)
        }
    }
}

