//
//  ContentView.swift
//  The Algorithm - Companion
//
//  Created by David Proctor on 10/29/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AuthenticationViewModel()
    @State private var showAuthenticationFlow = false
    
    var body: some View {
        DashboardView(viewModel: viewModel) {
            showAuthenticationFlow = true
        }
        .onAppear { updateAuthenticationPresentation() }
        .onChange(of: viewModel.hasOAuthToken) { _ in updateAuthenticationPresentation() }
        .onChange(of: viewModel.hasCookies) { _ in updateAuthenticationPresentation() }
        .fullScreenCover(isPresented: $showAuthenticationFlow) {
            AuthenticationFlowView(viewModel: viewModel) {
                updateAuthenticationPresentation()
            }
            .interactiveDismissDisabled(!(viewModel.hasOAuthToken && viewModel.hasCookies))
        }
    }
    
    private func updateAuthenticationPresentation() {
        let isAuthenticated = viewModel.hasOAuthToken && viewModel.hasCookies
        showAuthenticationFlow = !isAuthenticated
    }
}

// MARK: - Authentication Flow

private struct AuthenticationFlowView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    let dismissAction: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.1),
                        Color.purple.opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                                .padding(.top, 40)
                            
                            Text("The Algorithm")
                                .font(.system(size: 32, weight: .bold))
                            
                            Text("Companion")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 20)
                        
                        StatusCardView(viewModel: viewModel)
                        
                        VStack(spacing: 16) {
                            AuthButton(
                                title: "Authenticate with The Algorithm",
                                subtitle: "Step 1: OAuth Authentication",
                                systemImage: "key.fill",
                                isEnabled: !viewModel.hasOAuthToken,
                                isComplete: viewModel.hasOAuthToken,
                                action: { viewModel.authenticateWithOAuth() }
                            )
                            
                            AuthButton(
                                title: "Authenticate with X.com",
                                subtitle: "Step 2: Extract Session Cookies",
                                systemImage: "bird.fill",
                                isEnabled: viewModel.hasOAuthToken && !viewModel.hasCookies,
                                isComplete: viewModel.hasCookies,
                                action: { viewModel.authenticateWithTwitter() }
                            )
                        }
                        .padding(.horizontal)
                        
                        if viewModel.hasOAuthToken && viewModel.hasCookies {
                            MessageSectionView(viewModel: viewModel)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { viewModel.checkAPIHealth() }) {
                            Label("Check API Health", systemImage: "heart.text.square")
                        }
                        
                        if viewModel.hasOAuthToken || viewModel.hasCookies {
                            Divider()
                            Button(action: { viewModel.logoutAndReauthenticate() }) {
                                Label("Log Out & Reauthenticate", systemImage: "arrow.uturn.left.circle")
                            }
                            Button(role: .destructive, action: { viewModel.clearAllData() }) {
                                Label("Clear All Data", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert(item: $viewModel.alertMessage) { message in
                Alert(
                    title: Text(message.title),
                    message: Text(message.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .overlay {
                if viewModel.isLoading {
                    LoadingOverlay(message: viewModel.loadingMessage)
                }
            }
            .onAppear { viewModel.updateAuthenticationState() }
            .onChange(of: viewModel.hasOAuthToken && viewModel.hasCookies) { isReady in
                if isReady {
                    dismissAction()
                }
            }
        }
    }
}

// MARK: - Dashboard

private struct DashboardView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    let onRequestAuthenticationFlow: () -> Void
    
    var body: some View {
        let isAuthenticated = viewModel.hasOAuthToken && viewModel.hasCookies
        
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 24) {
                        StatusCardView(viewModel: viewModel)
                        AuthenticationChecklistView(viewModel: viewModel, onRequestAuthFlow: onRequestAuthenticationFlow)
                        if viewModel.hasOAuthToken && viewModel.hasCookies {
                            MessageSectionView(viewModel: viewModel)
                        } else {
                            AuthenticationHelpCard()
                        }
                    }
                    .padding(.vertical)
                }
                .navigationTitle("Overview")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: { viewModel.checkAPIHealth() }) {
                                Label("Check API Health", systemImage: "heart.text.square")
                            }
                            Divider()
                            Button(action: { viewModel.logoutAndReauthenticate() }) {
                                Label("Log Out & Reauthenticate", systemImage: "arrow.uturn.left.circle")
                            }
                            Button(role: .destructive, action: { viewModel.clearAllData() }) {
                                Label("Clear All Data", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .tabItem { Label("Overview", systemImage: "house") }
            
            NavigationStack {
                FeedView(apiClient: viewModel.apiClient, isAuthenticated: isAuthenticated)
            }
            .tabItem { Label("Feed", systemImage: "text.bubble") }
            
            NavigationStack {
                PostingQueueView(apiClient: viewModel.apiClient, isAuthenticated: isAuthenticated)
            }
            .tabItem { Label("Queue", systemImage: "tray.full") }
            
            NavigationStack {
                DraftsView(apiClient: viewModel.apiClient, isAuthenticated: isAuthenticated)
            }
            .tabItem { Label("Drafts", systemImage: "doc.text") }
            
            NavigationStack {
                MonitoredUsersView(apiClient: viewModel.apiClient, isAuthenticated: isAuthenticated)
            }
            .tabItem { Label("Users", systemImage: "person.3") }
            
            NavigationStack {
                SettingsStatusView(apiClient: viewModel.apiClient, isAuthenticated: isAuthenticated)
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

// MARK: - Dashboard Helper Views

private struct AuthenticationChecklistView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    let onRequestAuthFlow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Authentication Checklist")
                .font(.headline)

            Text("Complete both steps to unlock posting and data access.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            AuthButton(
                title: viewModel.hasOAuthToken ? "OAuth Connected" : "Authenticate with The Algorithm",
                subtitle: "Step 1: OAuth Authentication",
                systemImage: "key.fill",
                isEnabled: !viewModel.hasOAuthToken,
                isComplete: viewModel.hasOAuthToken,
                action: { viewModel.authenticateWithOAuth() }
            )

            AuthButton(
                title: viewModel.hasCookies ? "X.com Session Imported" : "Authenticate with X.com",
                subtitle: "Step 2: Extract Session Cookies",
                systemImage: "bird.fill",
                isEnabled: viewModel.hasOAuthToken && !viewModel.hasCookies,
                isComplete: viewModel.hasCookies,
                action: { viewModel.authenticateWithTwitter() }
            )

            Button(action: onRequestAuthFlow) {
                Label("Open Full Authentication Flow", systemImage: "rectangle.and.arrow.up.right")
            }
            .buttonStyle(.borderless)
            .font(.footnote)
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

private struct AuthenticationHelpCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sign-in Required")
                .font(.headline)
            Text("Authenticate with both The Algorithm backend and X.com to enable feed, queue, drafts, and posting. Use the buttons above to start the flow.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 1)
        .padding(.horizontal)
    }
}

// MARK: - Status Card View

struct StatusCardView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundColor(statusColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.headline)
                        .foregroundColor(statusColor)
                    
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .padding(.horizontal)
    }
    
    private var statusIcon: String {
        if viewModel.hasOAuthToken && viewModel.hasCookies {
            return "checkmark.circle.fill"
        } else if viewModel.hasOAuthToken {
            return "arrow.right.circle.fill"
        } else {
            return "info.circle.fill"
        }
    }
    
    private var statusColor: Color {
        if viewModel.hasOAuthToken && viewModel.hasCookies {
            return .green
        } else if viewModel.hasOAuthToken {
            return .orange
        } else {
            return .blue
        }
    }
    
    private var statusTitle: String {
        if viewModel.hasOAuthToken && viewModel.hasCookies {
            return "Ready to Send Messages"
        } else if viewModel.hasOAuthToken {
            return "OAuth Complete"
        } else {
            return "Welcome"
        }
    }
    
    private var statusMessage: String {
        if viewModel.hasOAuthToken && viewModel.hasCookies {
            return "All authentication steps completed successfully"
        } else if viewModel.hasOAuthToken {
            return "Now authenticate with X.com to extract cookies"
        } else {
            return "Start by authenticating with The Algorithm"
        }
    }
}

// MARK: - Auth Button

struct AuthButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isEnabled: Bool
    let isComplete: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: isComplete ? "checkmark" : systemImage)
                        .font(.title3)
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(textColor)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
    
    private var iconBackgroundColor: Color {
        if isComplete {
            return .green.opacity(0.2)
        } else if isEnabled {
            return .blue.opacity(0.2)
        } else {
            return Color(.systemGray5)
        }
    }
    
    private var iconColor: Color {
        if isComplete {
            return .green
        } else if isEnabled {
            return .blue
        } else {
            return .gray
        }
    }
    
    private var textColor: Color {
        isEnabled ? .primary : .secondary
    }
    
    private var backgroundColor: Color {
        Color(.systemBackground)
    }
}

// MARK: - Message Section

struct MessageSectionView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @State private var messageText: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Send a Message")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                TextField("Enter your message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                
                Button(action: {
                    viewModel.sendMessage(messageText)
                    messageText = ""
                }) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Send Message")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(messageText.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
        }
        .padding(.top)
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(Color(.systemGray6))
            .cornerRadius(15)
            .shadow(radius: 10)
        }
    }
}

#Preview {
    ContentView()
}
