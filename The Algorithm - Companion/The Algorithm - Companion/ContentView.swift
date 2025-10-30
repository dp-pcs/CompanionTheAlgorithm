//
//  ContentView.swift
//  The Algorithm - Companion
//
//  Created by David Proctor on 10/29/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AuthenticationViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
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
                        // Header
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
                        
                        // Status Card
                        StatusCardView(viewModel: viewModel)
                        
                        // Authentication Flow
                        VStack(spacing: 16) {
                            // OAuth Authentication
                            AuthButton(
                                title: "Authenticate with The Algorithm",
                                subtitle: "Step 1: OAuth Authentication",
                                systemImage: "key.fill",
                                isEnabled: !viewModel.hasOAuthToken,
                                isComplete: viewModel.hasOAuthToken,
                                action: { viewModel.authenticateWithOAuth() }
                            )
                            
                            // X.com Authentication
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
                        
                        // Message Section
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
        }
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
