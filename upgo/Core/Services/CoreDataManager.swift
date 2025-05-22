import Foundation
import CoreData
import SwiftUI

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private let persistentContainer: NSPersistentContainer
    
    private init() {
        persistentContainer = NSPersistentContainer(name: "UpBank")
        persistentContainer.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }
    
    // MARK: - Core Data Context
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    // MARK: - Budget Operations
    
    /// Saves a budget to Core Data
    func saveBudget(_ budget: Budget) {
        let context = viewContext
        
        // Create a new CDBudget entity
        let budgetEntity = CDBudget(context: context)
        budgetEntity.budgetId = budget.id
        budgetEntity.name = budget.name
        budgetEntity.targetAmountValue = String(format: "%.2f", budget.amount)
        budgetEntity.targetAmountValueInBaseUnits = Int64(budget.amount * 100)
        budgetEntity.startDate = budget.startDate
        budgetEntity.endDate = budget.endDate()
        budgetEntity.createdAt = Date()
        
        // Handle category
        if let categoryId = budget.categoryId {
            // Find the category in Core Data or create it
            let fetchRequest: NSFetchRequest<CDCategory> = CDCategory.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", categoryId)
            
            do {
                let categories = try context.fetch(fetchRequest)
                if let category = categories.first {
                    budgetEntity.addToCategories(category)
                } else {
                    // Create a new category if it doesn't exist
                    let newCategory = CDCategory(context: context)
                    newCategory.id = categoryId
                    newCategory.name = budget.category ?? "Unknown"
                    budgetEntity.addToCategories(newCategory)
                }
            } catch {
                print("Error fetching category: \(error)")
            }
        }
        
        // Handle tags
        for tagName in budget.tags {
            let fetchRequest: NSFetchRequest<CDTag> = CDTag.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", tagName)
            
            do {
                let tags = try context.fetch(fetchRequest)
                if let tag = tags.first {
                    budgetEntity.addToTags(tag)
                } else {
                    // Create a new tag if it doesn't exist
                    let newTag = CDTag(context: context)
                    newTag.id = tagName
                    budgetEntity.addToTags(newTag)
                }
            } catch {
                print("Error fetching tag: \(error)")
            }
        }
        
        // Save the context
        saveContext()
    }
    
    /// Fetches all budgets from Core Data
    func fetchBudgets() -> [Budget] {
        let fetchRequest: NSFetchRequest<CDBudget> = CDBudget.fetchRequest()
        
        do {
            let budgetEntities = try viewContext.fetch(fetchRequest)
            
            return budgetEntities.map { entity in
                let budget = Budget(
                    id: entity.budgetId ?? UUID(),
                    name: entity.name ?? "Unnamed Budget",
                    amount: Double(entity.targetAmountValueInBaseUnits) / 100.0,
                    spent: 0.0, // We'll calculate this separately
                    category: entity.categories?.anyObject() as? CDCategory != nil ? (entity.categories?.anyObject() as? CDCategory)?.name : nil,
                    categoryId: entity.categories?.anyObject() as? CDCategory != nil ? (entity.categories?.anyObject() as? CDCategory)?.id : nil,
                    tags: (entity.tags?.allObjects as? [CDTag])?.compactMap { $0.id } ?? [],
                    period: determinePeriod(startDate: entity.startDate, endDate: entity.endDate),
                    startDate: entity.startDate ?? Date(),
                    color: .blue, // Default color, we'll need to store this in the future
                    isActive: true
                )
                return budget
            }
        } catch {
            print("Error fetching budgets: \(error)")
            return []
        }
    }
    
    /// Determine the budget period based on start and end dates
    private func determinePeriod(startDate: Date?, endDate: Date?) -> BudgetPeriod {
        guard let start = startDate, let end = endDate else {
            return .monthly // Default
        }
        
        let components = Calendar.current.dateComponents([.day, .month, .year], from: start, to: end)
        
        if let year = components.year, year > 0 {
            return .yearly
        } else if let month = components.month, month > 0 {
            return .monthly
        } else if let days = components.day {
            if days >= 6 && days <= 8 {
                return .weekly
            } else {
                return .custom(days: days)
            }
        }
        
        return .monthly // Default
    }
    
    /// Updates an existing budget in Core Data
    func updateBudget(_ budget: Budget) {
        let context = viewContext
        let fetchRequest: NSFetchRequest<CDBudget> = CDBudget.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "budgetId == %@", budget.id as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let budgetEntity = results.first {
                // Update the budget properties
                budgetEntity.name = budget.name
                budgetEntity.targetAmountValue = String(format: "%.2f", budget.amount)
                budgetEntity.targetAmountValueInBaseUnits = Int64(budget.amount * 100)
                budgetEntity.startDate = budget.startDate
                budgetEntity.endDate = budget.endDate()
                
                // Handle category updates
                if let existingCategories = budgetEntity.categories as? Set<CDCategory> {
                    for category in existingCategories {
                        budgetEntity.removeFromCategories(category)
                    }
                }
                
                if let categoryId = budget.categoryId {
                    // Find or create the category
                    let categoryFetchRequest: NSFetchRequest<CDCategory> = CDCategory.fetchRequest()
                    categoryFetchRequest.predicate = NSPredicate(format: "id == %@", categoryId)
                    
                    let categories = try context.fetch(categoryFetchRequest)
                    if let category = categories.first {
                        budgetEntity.addToCategories(category)
                    } else {
                        // Create a new category
                        let newCategory = CDCategory(context: context)
                        newCategory.id = categoryId
                        newCategory.name = budget.category ?? "Unknown"
                        budgetEntity.addToCategories(newCategory)
                    }
                }
                
                // Handle tag updates
                if let existingTags = budgetEntity.tags as? Set<CDTag> {
                    for tag in existingTags {
                        budgetEntity.removeFromTags(tag)
                    }
                }
                
                // Add new tags
                for tagName in budget.tags {
                    let tagFetchRequest: NSFetchRequest<CDTag> = CDTag.fetchRequest()
                    tagFetchRequest.predicate = NSPredicate(format: "id == %@", tagName)
                    
                    let tags = try context.fetch(tagFetchRequest)
                    if let tag = tags.first {
                        budgetEntity.addToTags(tag)
                    } else {
                        // Create a new tag
                        let newTag = CDTag(context: context)
                        newTag.id = tagName
                        budgetEntity.addToTags(newTag)
                    }
                }
                
                // Save the context
                saveContext()
            }
        } catch {
            print("Error updating budget: \(error)")
        }
    }
    
    /// Deletes a budget from Core Data
    func deleteBudget(withId id: UUID) {
        let context = viewContext
        let fetchRequest: NSFetchRequest<CDBudget> = CDBudget.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "budgetId == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let budgetEntity = results.first {
                context.delete(budgetEntity)
                saveContext()
            }
        } catch {
            print("Error deleting budget: \(error)")
        }
    }
} 