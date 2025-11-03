# Mobile App Subscription Flow Proposal

## Problem Statement
Users authenticating with the mobile app may:
1. Not have an account yet (new users)
2. Have an expired 14-day trial
3. Need to select a paid plan

The mobile app currently does not handle these lifecycle states.

## Current Backend Behavior

### ✅ What Works:
- **New User Auth**: Backend automatically creates account + starts 14-day trial
- **Subscription Validation**: Backend returns `402 Payment Required` when trial expires
- **Plan Tier Detection**: `/api/api-key-status` returns user's `plan_tier`

### ❌ What's Missing in Mobile:
- No detection of `402` subscription errors
- No "trial expired" UI
- No upgrade/payment flow
- No proactive subscription status checking

---

## Recommended Solution: Web-Based Upgrade Flow

### Why This Approach?
1. ✅ **Fast to implement** (1-2 days vs weeks for IAP)
2. ✅ **No Apple 30% commission** 
3. ✅ **Unified payment system** (Stripe on web works for both)
4. ✅ **Easier to update** pricing/plans without app store review
5. ✅ **No complex IAP receipt validation**

---

## Proposed User Flows

### Flow 1: New User (First Time)
```
┌─────────────────────────────────────────────────┐
│ User: Opens mobile app                          │
│ App:  Shows "Authenticate with OAuth" button    │
│ User: Taps button                                │
│ App:  Redirects to web OAuth                     │
│ Web:  User logs in with X.com                    │
│ Backend: Creates account + 14-day trial starts   │
│ Web:  Redirects back to mobile app               │
│ App:  Stores OAuth token                         │
│ App:  Shows dashboard with full access ✅        │
│                                                   │
│ Status: ALREADY WORKS - no changes needed        │
└─────────────────────────────────────────────────┘
```

### Flow 2: Trial User (Mid-Trial)
```
┌─────────────────────────────────────────────────┐
│ User: Opens app (Day 5 of 14)                    │
│ App:  Calls /api/api-key-status                  │
│ Backend: Returns plan_tier: "free"               │
│ App:  Shows banner: "9 days left in trial"       │
│ User: Continues using app normally ✅             │
└─────────────────────────────────────────────────┘
```

### Flow 3: Trial Expired (Needs Upgrade)
```
┌──────────────────────────────────────────────────┐
│ User: Opens app (Day 15+)                         │
│ App:  Makes API call (e.g., generate replies)     │
│ Backend: Returns 402 Payment Required:            │
│         {                                          │
│           "error": "subscription_required",       │
│           "subscription_status": "trial_expired", │
│           "days_expired": 1,                       │
│           "upgrade_url": "/pricing"               │
│         }                                          │
│ App:  Shows full-screen "Trial Expired" modal:    │
│       ┌────────────────────────────────────┐     │
│       │ 🔒 Your Trial Has Ended             │     │
│       │                                      │     │
│       │ Your 14-day trial expired 1 day ago.│     │
│       │ Choose a plan to continue using     │     │
│       │ The Algorithm.                       │     │
│       │                                      │     │
│       │ [View Plans & Pricing] ←─── Opens   │     │
│       │                         web browser  │     │
│       │                                      │     │
│       │ [Logout]                             │     │
│       └────────────────────────────────────┘     │
│ User: Taps "View Plans & Pricing"                 │
│ App:  Opens Safari to:                             │
│       https://thealgorithm.live/pricing            │
│ User: Selects plan, enters payment (Stripe)       │
│ Web:  Payment succeeds, updates DB                 │
│ User: Returns to mobile app                        │
│ App:  Auto-retries last failed API call            │
│ Backend: Now returns 200 OK ✅                     │
│ App:  Dismisses modal, shows dashboard            │
└──────────────────────────────────────────────────┘
```

### Flow 4: Paid User (Active Subscription)
```
┌─────────────────────────────────────────────────┐
│ User: Opens app                                  │
│ App:  Makes API calls                            │
│ Backend: Returns 200 OK                          │
│ App:  Full access to all features ✅             │
└─────────────────────────────────────────────────┘
```

---

## Technical Implementation

### 1. Update `APIClient.swift`

Add subscription error detection:

```swift
private func performRequest<T: Codable>(
    path: String,
    // ... existing params
) {
    // ... existing code
    
    // Check for subscription errors
    if httpResponse.statusCode == 402 {
        if let errorData = try? JSONDecoder().decode(SubscriptionError.self, from: data) {
            // Post notification to show subscription modal
            NotificationCenter.default.post(
                name: .subscriptionRequired,
                object: errorData
            )
        }
        completion(.failure(APIError.subscriptionRequired))
        return
    }
}

// New error type
enum APIError: Error {
    case subscriptionRequired
    // ... existing errors
}

// New struct for 402 error details
struct SubscriptionError: Codable {
    let error: String
    let message: String
    let subscriptionStatus: String
    let daysExpired: Int?
    let trialEndDate: String?
    let upgradeUrl: String
    
    enum CodingKeys: String, CodingKey {
        case error, message
        case subscriptionStatus = "subscription_status"
        case daysExpired = "days_expired"
        case trialEndDate = "trial_end_date"
        case upgradeUrl = "upgrade_url"
    }
}
```

### 2. Create `SubscriptionManager.swift`

```swift
import Foundation
import Combine

class SubscriptionManager: ObservableObject {
    @Published var showPaywall = false
    @Published var subscriptionError: SubscriptionError?
    @Published var planTier: String = "free"
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Listen for subscription errors
        NotificationCenter.default.publisher(for: .subscriptionRequired)
            .sink { [weak self] notification in
                if let error = notification.object as? SubscriptionError {
                    self?.handleSubscriptionRequired(error)
                }
            }
            .store(in: &cancellables)
    }
    
    func checkSubscriptionStatus(apiClient: APIClient) {
        apiClient.fetchAPIKeyStatus { [weak self] result in
            switch result {
            case .success(let status):
                self?.planTier = status.planTier
            case .failure:
                break
            }
        }
    }
    
    private func handleSubscriptionRequired(_ error: SubscriptionError) {
        subscriptionError = error
        showPaywall = true
    }
    
    func openPricingPage() {
        let urlString = "https://thealgorithm.live\(subscriptionError?.upgradeUrl ?? "/pricing")"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

extension Notification.Name {
    static let subscriptionRequired = Notification.Name("subscriptionRequired")
}
```

### 3. Create `SubscriptionPaywallView.swift`

```swift
import SwiftUI

struct SubscriptionPaywallView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)
            
            Text("Subscription Required")
                .font(.title)
                .fontWeight(.bold)
            
            if let error = subscriptionManager.subscriptionError {
                Text(error.message)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                if let daysExpired = error.daysExpired {
                    Text("Trial expired \(daysExpired) day\(daysExpired == 1 ? "" : "s") ago")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    subscriptionManager.openPricingPage()
                }) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                        Text("View Plans & Pricing")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 6/255, green: 182/255, blue: 212/255))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button("Logout") {
                    // Handle logout
                }
                .foregroundColor(.red)
            }
            .padding(.horizontal)
        }
        .padding(32)
    }
}
```

### 4. Update `ContentView.swift`

```swift
@StateObject private var subscriptionManager = SubscriptionManager()

var body: some View {
    // ... existing code
    .sheet(isPresented: $subscriptionManager.showPaywall) {
        SubscriptionPaywallView(subscriptionManager: subscriptionManager)
            .interactiveDismissDisabled() // Prevent dismissal without action
    }
    .onAppear {
        if authViewModel.isAuthenticated {
            subscriptionManager.checkSubscriptionStatus(apiClient: apiClient)
        }
    }
}
```

### 5. Add Trial Status Banner (Optional Enhancement)

Show remaining trial days to encourage upgrades:

```swift
struct TrialStatusBanner: View {
    let daysRemaining: Int
    
    var body: some View {
        HStack {
            Image(systemName: "clock.fill")
            Text("\(daysRemaining) days left in trial")
            Spacer()
            Button("Upgrade") {
                // Open pricing
            }
            .font(.caption)
            .fontWeight(.semibold)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .foregroundColor(.orange)
    }
}
```

---

## Alternative: In-App Browser (Enhanced UX)

Instead of opening Safari, use `SFSafariViewController` for a more integrated experience:

```swift
import SafariServices

func openPricingInApp() {
    guard let url = URL(string: "https://thealgorithm.live/pricing") else { return }
    
    let safariVC = SFSafariViewController(url: url)
    safariVC.preferredControlTintColor = UIColor(red: 6/255, green: 182/255, blue: 212/255, alpha: 1)
    
    // Present from root view controller
    UIApplication.shared.windows.first?.rootViewController?.present(safariVC, animated: true)
}
```

**Benefits:**
- User stays "in the app"
- Automatic cookies/session sharing
- Dismiss returns immediately to app

---

## Backend Requirements (Already Implemented)

✅ **No backend changes needed!** The backend already:
1. Creates accounts + starts trials on first OAuth
2. Returns `402` errors with subscription details
3. Provides `/api/api-key-status` for plan tier checking
4. Handles payment processing via Stripe

---

## Testing Scenarios

### Test 1: New User
1. Delete app
2. Reinstall
3. Authenticate with X.com
4. Verify: Full access immediately

### Test 2: Expired Trial
1. Ask backend team to manually expire a test user's trial
2. Open app
3. Make any API call (e.g., generate replies)
4. Verify: Paywall appears with correct message

### Test 3: Payment Flow
1. Trigger paywall
2. Tap "View Plans"
3. Complete payment on web
4. Return to app
5. Verify: API calls now succeed

### Test 4: Active Subscriber
1. Login as paid user
2. Verify: No paywall, full access

---

## Implementation Timeline

**Estimated: 1-2 days**

- [ ] Day 1 Morning: Add `402` error detection to `APIClient`
- [ ] Day 1 Afternoon: Create `SubscriptionManager` and paywall view
- [ ] Day 1 Evening: Test with manually expired trial
- [ ] Day 2 Morning: Add trial status banner (optional)
- [ ] Day 2 Afternoon: End-to-end testing
- [ ] Day 2 Evening: Backend team testing

---

## Future Enhancements (Post-MVP)

1. **Deep Linking**: Return to app automatically after web payment
2. **Proactive Notifications**: "3 days left in trial" reminder
3. **Plan Comparison**: Show plan features before redirecting
4. **IAP Option**: Add Apple In-App Purchase for users who prefer it
5. **Family Sharing**: Support for shared subscriptions

---

## Decision Required

**Question for team:** 

Which approach do you prefer?

A. **Web-Based (Recommended)**: Redirect to web pricing page  
   - Pros: Fast, no Apple commission, unified payment  
   - Cons: User leaves app temporarily

B. **In-App Browser**: Use SFSafariViewController  
   - Pros: User stays "in app", better UX  
   - Cons: Slightly more complex

C. **Apple IAP**: Native in-app purchase  
   - Pros: Native iOS experience  
   - Cons: 30% commission, complex, slower to implement

**My recommendation: Start with A or B, add C later if needed.**

