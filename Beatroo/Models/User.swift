import Foundation
import FirebaseFirestore

struct User: Codable {
    let uid: String
    var email: String
    var displayName: String
    var username: String
    var photoURL: String?
    var age: Int? // Deprecated - kept for backward compatibility
    var dateOfBirth: Date?
    var gender: Gender
    var customGender: String?
    var createdAt: Date
    var updatedAt: Date
    
    // Google Sign-In info
    var googleId: String?
    
    // Computed property to calculate current age from date of birth
    var currentAge: Int? {
        guard let dateOfBirth = dateOfBirth else {
            // Fallback to stored age for backward compatibility
            return age
        }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        return ageComponents.year
    }
    
    var isProfileComplete: Bool {
        return !username.isEmpty && 
               !displayName.isEmpty && 
               age != nil && 
               photoURL != nil
    }
}

enum Gender: String, Codable, CaseIterable {
    case male = "Male"
    case female = "Female"
    case nonBinary = "Non-Binary"
    case custom = "Custom"
    case preferNotToSay = "Prefer not to say"
    
    var displayName: String {
        return self.rawValue
    }
}

struct UserStats: Codable {
    let userId: String
    var totalScore: Double
    let lastUpdated: Date
    let city: String
    
    init(userId: String, totalScore: Double = 0.0, lastUpdated: Date = Date(), city: String) {
        self.userId = userId
        self.totalScore = totalScore
        self.lastUpdated = lastUpdated
        self.city = city
    }
}

struct DailyLeaderboard: Codable {
    let city: String
    let date: String
    let entries: [LeaderboardEntry]
    let lastUpdated: Date
    
    init(city: String, date: String, entries: [LeaderboardEntry] = [], lastUpdated: Date = Date()) {
        self.city = city
        self.date = date
        self.entries = entries
        self.lastUpdated = lastUpdated
    }
}

struct LeaderboardEntry: Codable {
    let userId: String
    let username: String
    let displayName: String
    let totalScore: Double
    let rank: Int
    
    init(userId: String, username: String, displayName: String, totalScore: Double, rank: Int) {
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.totalScore = totalScore
        self.rank = rank
    }
}

extension User {
    static func empty(uid: String, email: String) -> User {
        return User(
            uid: uid,
            email: email,
            displayName: "",
            username: "",
            photoURL: nil,
            age: nil,
            dateOfBirth: nil,
            gender: .preferNotToSay,
            customGender: nil,
            createdAt: Date(),
            updatedAt: Date(),
            googleId: nil
        )
    }
} 