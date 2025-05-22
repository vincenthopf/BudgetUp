//
//  upgoApp.swift
//  upgo
//
//  Created by Vincent Hopf on 20/5/2025.
//

import SwiftUI

@main
struct upgoApp: App {
    // Create shared instances of the view models
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var accountsViewModel = AccountsViewModel()
    @StateObject private var transactionsViewModel = TransactionsViewModel()
    @StateObject private var budgetViewModel = BudgetViewModel()
    
    // Create the persistence controller for CoreData
    let persistenceController = PersistenceController.shared
    
    init() {
        // Initialize the AccountsViewModel with its default constructor
        // The StateObject wrappers will properly initialize the view models
        let transactionsVM = TransactionsViewModel()
        _transactionsViewModel = StateObject(wrappedValue: transactionsVM)
        
        let accountsVM = AccountsViewModel(transactionsViewModel: transactionsVM)
        _accountsViewModel = StateObject(wrappedValue: accountsVM)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(accountsViewModel)
                .environmentObject(transactionsViewModel)
                .environmentObject(budgetViewModel)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
