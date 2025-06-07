import Foundation
import FirebaseFirestore

struct User: Codable {
    let uid: String
    var email: String
    var displayName: String
    var username: String
    var photoURL: String?
    var age: Int?
    var gender: Gender
    var customGender: String?
    var createdAt: Date
    var updatedAt: Date
    
    // Google Sign-In info
    var googleId: String?
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

extension User {
    static func empty(uid: String, email: String) -> User {
        return User(
            uid: uid,
            email: email,
            displayName: "",
            username: "",
            photoURL: nil,
            age: nil,
            gender: .preferNotToSay,
            customGender: nil,
            createdAt: Date(),
            updatedAt: Date(),
            googleId: nil
        )
    }
} 