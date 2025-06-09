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
               (currentAge != nil || age != nil) && 
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