import Foundation
import SwiftUI

// MARK: - Budget Models
struct Budget: Identifiable, Equatable {
    let id: UUID
    var name: String
    var amount: Double
    var spent: Double
    var category: String?
    var categoryId: String?
    var tags: [String]
    var period: BudgetPeriod
    var startDate: Date
    var color: Color
    var isActive: Bool
    
    init(id: UUID = UUID(), 
         name: String, 
         amount: Double, 
         spent: Double = 0.0, 
         category: String? = nil,
         categoryId: String? = nil,
         tags: [String] = [], 
         period: BudgetPeriod = .monthly, 
         startDate: Date = Date(), 
         color: Color = .blue, 
         isActive: Bool = true) {
        self.id = id
        self.name = name
        self.amount = amount
        self.spent = spent
        self.category = category
        self.categoryId = categoryId
        self.tags = tags
        self.period = period
        self.startDate = startDate
        self.color = color
        self.isActive = isActive
    }
    
    var progressPercentage: Double {
        guard amount > 0 else { return 0 }
        return min(spent / amount, 1.0)
    }
    
    var remaining: Double {
        return max(amount - spent, 0)
    }
    
    var isOverBudget: Bool {
        return spent > amount
    }
    
    func endDate() -> Date {
        switch period {
        case .weekly:
            return Calendar.current.date(byAdding: .day, value: 7, to: startDate) ?? startDate
        case .monthly:
            return Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case .yearly:
            return Calendar.current.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        case .custom(let days):
            return Calendar.current.date(byAdding: .day, value: days, to: startDate) ?? startDate
        }
    }
    
    static func == (lhs: Budget, rhs: Budget) -> Bool {
        return lhs.id == rhs.id
    }
}

enum BudgetPeriod: Equatable, Hashable {
    case weekly
    case monthly
    case yearly
    case custom(days: Int)
    
    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .custom(let days): return "\(days) days"
        }
    }
}

// MARK: - Core Data Extensions for later implementation
extension Budget {
    // Will be used for mapping to/from Core Data when that's implemented
    init(from entity: BudgetEntity) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? ""
        self.amount = entity.amount
        self.spent = entity.spent
        self.category = entity.category
        self.categoryId = entity.categoryId
        self.tags = entity.tags?.components(separatedBy: ",") ?? []
        
        // Convert stored period string to enum
        if let periodString = entity.period {
            if periodString == "weekly" {
                self.period = .weekly
            } else if periodString == "monthly" {
                self.period = .monthly
            } else if periodString == "yearly" {
                self.period = .yearly
            } else if periodString.starts(with: "custom:") {
                let daysString = periodString.replacingOccurrences(of: "custom:", with: "")
                if let days = Int(daysString) {
                    self.period = .custom(days: days)
                } else {
                    self.period = .monthly // Default
                }
            } else {
                self.period = .monthly // Default
            }
        } else {
            self.period = .monthly // Default
        }
        
        self.startDate = entity.startDate ?? Date()
        
        // Convert stored color string to Color
        if let colorString = entity.colorHex {
            self.color = Color(hex: colorString) ?? .blue
        } else {
            self.color = .blue
        }
        
        self.isActive = entity.isActive
    }
}

// Placeholder for future Core Data integration
class BudgetEntity {
    var id: UUID?
    var name: String?
    var amount: Double = 0
    var spent: Double = 0
    var category: String?
    var categoryId: String?
    var tags: String?
    var period: String?
    var startDate: Date?
    var colorHex: String?
    var isActive: Bool = true
}

// Color extension for hex conversion
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        let hexString = String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        return hexString
    }
} 