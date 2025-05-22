//
//  ContentView.swift
//  upgo
//
//  Created by Vincent Hopf on 20/5/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabView()
            } else {
                AuthenticationView()
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var accountsViewModel: AccountsViewModel
    @EnvironmentObject private var transactionsViewModel: TransactionsViewModel
    @StateObject private var budgetViewModel = BudgetViewModel()
    
    var body: some View {
        TabView {
            DashboardView(accountsViewModel: accountsViewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "house")
                }
            
            TransactionsListView(viewModel: transactionsViewModel)
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet")
                }
            
            BudgetsListView(viewModel: budgetViewModel)
                .tabItem {
                    Label("Budgets", systemImage: "chart.pie")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onAppear {
            Task {
                await budgetViewModel.loadBudgets()
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button("Sign Out") {
                        authViewModel.signOut()
                    }
                    .foregroundColor(.red)
                    
                    Button("Delete Token") {
                        Task {
                            await authViewModel.deleteToken()
                        }
                    }
                    .foregroundColor(.red)
                } header: {
                    Text("Account")
                }
                
                Section {
                    HStack {
                        Text("Biometrics")
                        Spacer()
                        Text(authViewModel.biometricType)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct AuthenticationView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            if authViewModel.hasToken {
                BiometricAuthView()
            } else {
                TokenInputView(viewModel: authViewModel)
            }
        }
    }
}

struct BiometricAuthView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: authViewModel.biometricType == "Face ID" ? "faceid" : "touchid")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("Welcome Back")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Authenticate to access your Up Bank data")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
            
            if let error = authViewModel.error {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Button {
                isLoading = true
                Task {
                    await authViewModel.authenticate()
                    isLoading = false
                }
            } label: {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Authenticate with \(authViewModel.biometricType)")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue)
            )
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            
            Button {
                Task {
                    await authViewModel.deleteToken()
                }
            } label: {
                Text("Use a different token")
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 32)
        }
        .onAppear {
            Task {
                await authViewModel.authenticate()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
        .environmentObject(AccountsViewModel())
        .environmentObject(TransactionsViewModel())
}
