import SwiftUI

struct TrialStatusBanner: View {
    let planTier: String
    let onUpgradeAction: () -> Void
    
    var body: some View {
        if planTier == "free" {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.checkmark.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Free Trial Active")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    
                    Text("Upgrade anytime for full access")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onUpgradeAction) {
                    Text("Upgrade")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 6/255, green: 182/255, blue: 212/255))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color(red: 6/255, green: 182/255, blue: 212/255).opacity(0.1))
                        .cornerRadius(16)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.top, 8)
        } else if planTier == "starter" {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(red: 6/255, green: 182/255, blue: 212/255))
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Starter Plan")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("Add LLM keys to unlock features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onUpgradeAction) {
                    Text("Upgrade")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 6/255, green: 182/255, blue: 212/255))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color(red: 6/255, green: 182/255, blue: 212/255).opacity(0.1))
                        .cornerRadius(16)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.top, 8)
        }
        // Don't show banner for pro/pro_plus users
    }
}

// MARK: - Preview
struct TrialStatusBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            TrialStatusBanner(planTier: "free") {
                print("Upgrade tapped")
            }
            
            TrialStatusBanner(planTier: "starter") {
                print("Upgrade tapped")
            }
            
            TrialStatusBanner(planTier: "pro") {
                print("Upgrade tapped")
            }
        }
        .padding()
    }
}

