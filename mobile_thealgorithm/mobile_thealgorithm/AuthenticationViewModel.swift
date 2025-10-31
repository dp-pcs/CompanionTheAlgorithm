//
//  AuthenticationViewModel.swift
//  The Algorithm - Companion
//
//  Created by David Proctor on 10/30/25.
//

import SwiftUI
import Combine

class AuthenticationViewModel: ObservableObject {
    @Published var hasOAuthToken: Bool = false
    @Published var hasCookies: Bool = false
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String = ""
    @Published var alertMessage: AlertMessage?
    
    private let authManager = AuthenticationManager()
    private let cookieManager = CookieManager()
    let apiClient = APIClient()
    
    init() {
        // Check initial authentication state
        updateAuthenticationState()
    }
    
    // MARK: - Authentication State
    
    func updateAuthenticationState() {
        hasOAuthToken = authManager.hasValidOAuthToken()
        hasCookies = cookieManager.hasValidCookies()
    }
    
    // MARK: - OAuth Authentication
    
    func authenticateWithOAuth() {
        isLoading = true
        loadingMessage = "Authenticating with The Algorithm..."
        
        // Add timeout
        let timeout = DispatchWorkItem { [weak self] in
            self?.isLoading = false
            self?.showAlert(
                title: "Authentication Timeout",
                message: "The authentication request took too long. Please check your internet connection and try again."
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: timeout)
        
        authManager.authenticateWithOAuth { [weak self] success, error in
            DispatchQueue.main.async {
                timeout.cancel() // Cancel timeout if we got a response
                self?.isLoading = false
                
                if success {
                    self?.updateAuthenticationState()
                    self?.showAlert(
                        title: "Success! ✅",
                        message: "OAuth authentication completed successfully. Now authenticate with X.com to continue."
                    )
                } else {
                    let errorMessage = error?.localizedDescription ?? "Failed to authenticate with The Algorithm. Please try again."
                    print("❌ OAuth Error: \(errorMessage)")
                    self?.showAlert(
                        title: "Authentication Failed",
                        message: errorMessage
                    )
                }
            }
        }
    }
    
    // MARK: - Twitter/X.com Authentication
    
    func authenticateWithTwitter() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            showAlert(title: "Error", message: "Unable to present authentication view")
            return
        }
        
        // Find the presented view controller or use root
        let presentingVC = rootViewController.presentedViewController ?? rootViewController
        
        isLoading = true
        loadingMessage = "Opening X.com authentication..."
        
        // Small delay to show loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            self.isLoading = false
            
            self.authManager.authenticateWithTwitter(from: presentingVC) { [weak self] cookies, error in
                DispatchQueue.main.async {
                    if let cookies = cookies, !cookies.isEmpty {
                        // Store cookies locally
                        self?.cookieManager.storeCookies(cookies)
                        
                        // Send cookies to backend
                        self?.sendCookiesToBackend(cookies)
                        
                        self?.updateAuthenticationState()
                        
                        self?.showAlert(
                            title: "Success! 🎉",
                            message: "X.com authentication completed successfully. You're all set!"
                        )
                    } else {
                        self?.showAlert(
                            title: "Authentication Failed",
                            message: error?.localizedDescription ?? "Failed to authenticate with X.com. Please try again."
                        )
                    }
                }
            }
        }
    }
    
    private func sendCookiesToBackend(_ cookies: [HTTPCookie]) {
        apiClient.storeCookies(cookies) { success, error in
            if success {
                print("✅ Cookies successfully sent to backend")
            } else {
                print("⚠️ Warning: Failed to send cookies to backend: \(error?.localizedDescription ?? "Unknown error")")
                // Don't show error to user since local storage succeeded
            }
        }
    }
    
    // MARK: - Message Sending
    
    func sendMessage(_ message: String) {
        guard !message.isEmpty else { return }
        
        isLoading = true
        loadingMessage = "Sending message..."
        
        apiClient.sendMessage(message) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if success {
                    self?.showAlert(
                        title: "Message Sent! 📨",
                        message: "Your message was sent successfully."
                    )
                } else {
                    self?.showAlert(
                        title: "Failed to Send",
                        message: error?.localizedDescription ?? "Unable to send message. Please try again."
                    )
                }
            }
        }
    }
    
    // MARK: - API Health Check
    
    func checkAPIHealth() {
        isLoading = true
        loadingMessage = "Checking API health..."
        
        apiClient.checkAPIHealth { [weak self] isHealthy, healthData in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if isHealthy {
                    var message = "API is operational and responding normally."
                    if let healthData = healthData, let version = healthData["version"] as? String {
                        message += "\n\nVersion: \(version)"
                    }
                    self?.showAlert(
                        title: "API Health: Good ✅",
                        message: message
                    )
                } else {
                    self?.showAlert(
                        title: "API Health: Issues ⚠️",
                        message: "The API is not responding. Please check your network connection and try again later."
                    )
                }
            }
        }
    }
    
    func checkAPIKeyStatus() {
        isLoading = true
        loadingMessage = "Checking API key status..."
        
        apiClient.fetchAPIKeyStatus { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let status):
                    var message = ""
                    
                    if status.usingSystemKeys {
                        message = "✅ You're using system-provided LLM keys (Pro/Pro+ user).\n\n"
                        message += "All features enabled! No additional setup needed."
                    } else if status.needsOwnKeys {
                        if status.availableProviders.isEmpty {
                            message = "⚠️ You need to add your own LLM API keys.\n\n"
                            message += "Please visit Settings on thealgorithm.live to add keys."
                        } else {
                            message = "✅ Your LLM keys are configured!\n\n"
                            message += "Available providers: \(status.availableProviders.joined(separator: ", "))"
                        }
                    }
                    
                    if status.isProUser {
                        message += "\n\n🌟 Pro User Status Active"
                    }
                    
                    self?.showAlert(
                        title: "API Key Status",
                        message: message
                    )
                    
                case .failure(let error):
                    self?.showAlert(
                        title: "Error Checking Keys",
                        message: "Failed to fetch API key status: \(error.localizedDescription)"
                    )
                }
            }
        }
    }
    
    // MARK: - Clear Data
    
    func clearAllData(showConfirmation: Bool = true) {
        // Clear OAuth token
        KeychainHelper.delete(service: "TheAlgorithm", account: "oauth_token")
        
        // Clear cookies
        cookieManager.clearCookies()
        
        // Update state
        updateAuthenticationState()
        
        print("🧼 Cleared authentication data")

        if showConfirmation {
            showAlert(
                title: "Data Cleared",
                message: "All authentication data has been removed. You'll need to authenticate again."
            )
        }
    }

    func logoutAndReauthenticate() {
        clearAllData(showConfirmation: false)
        showAlert(
            title: "Signed Out",
            message: "You're signed out. Start with OAuth again when you're ready."
        )
    }
    
    // MARK: - Alert Helper
    
    private func showAlert(title: String, message: String) {
        alertMessage = AlertMessage(title: title, message: message)
    }
}

// MARK: - Alert Message

struct AlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

