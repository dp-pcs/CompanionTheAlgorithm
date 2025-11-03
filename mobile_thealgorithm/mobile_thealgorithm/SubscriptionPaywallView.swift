import SwiftUI

struct SubscriptionPaywallView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @ObservedObject var authViewModel: AuthenticationViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                // Lock icon
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.red)
                    .padding(.bottom, 8)
                
                // Title
                Text("Subscription Required")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                
                // Message
                VStack(spacing: 12) {
                    if let error = subscriptionManager.subscriptionError {
                        Text(error.message)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        if let daysExpired = error.daysExpired, daysExpired > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.badge.exclamationmark")
                                Text("Trial expired \(daysExpired) day\(daysExpired == 1 ? "" : "s") ago")
                            }
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                    } else {
                        Text("Your trial has expired. Choose a plan to continue using The Algorithm.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    // Primary CTA: View Plans
                    Button(action: {
                        subscriptionManager.openPricingPage()
                    }) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                            Text("View Plans & Pricing")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 6/255, green: 182/255, blue: 212/255))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    // Secondary: I already subscribed
                    Button(action: {
                        // Dismiss and trigger a re-check
                        // This will retry the API call that failed
                        subscriptionManager.showPaywall = false
                    }) {
                        Text("I Already Subscribed")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color(red: 6/255, green: 182/255, blue: 212/255))
                    }
                    .padding(.top, 4)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Logout button
                    Button(action: {
                        authViewModel.logout()
                        subscriptionManager.showPaywall = false
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Logout")
                        }
                        .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .navigationBarHidden(true)
        }
        .interactiveDismissDisabled() // Prevent swipe to dismiss
    }
}

// MARK: - Preview
struct SubscriptionPaywallView_Previews: PreviewProvider {
    static var previews: some View {
        let subscriptionManager = SubscriptionManager()
        let authViewModel = AuthenticationViewModel()
        
        // Simulate expired trial
        subscriptionManager.subscriptionError = SubscriptionError(
            error: "subscription_required",
            message: "Your trial has expired. Please subscribe to continue using The Algorithm.",
            subscriptionStatus: "trial_expired",
            daysExpired: 3,
            trialEndDate: "2025-10-31T12:00:00Z",
            upgradeUrl: "/pricing"
        )
        subscriptionManager.showPaywall = true
        
        return SubscriptionPaywallView(
            subscriptionManager: subscriptionManager,
            authViewModel: authViewModel
        )
    }
}

