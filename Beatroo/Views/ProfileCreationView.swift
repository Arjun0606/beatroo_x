import SwiftUI
import PhotosUI

struct ProfileCreationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var displayName = ""
    @State private var username = ""
    @State private var dateOfBirth = Date()
    @State private var showDatePicker = false
    @State private var selectedGender = Gender.preferNotToSay
    @State private var customGender = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Calculate age from date of birth
    var age: Int? {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        return ageComponents.year
    }
    
    // Check if user is at least 13 years old
    var isValidAge: Bool {
        guard let userAge = age else { return false }
        return userAge >= 13
    }
    
    var isFormValid: Bool {
        !displayName.isEmpty &&
        !username.isEmpty &&
        isValidAge &&
        selectedImage != nil &&
        (selectedGender != .custom || !customGender.isEmpty)
    }
    
    // Date formatter for display
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }
    
    // Maximum date (must be at least 13 years old)
    var maximumDate: Date {
        Calendar.current.date(byAdding: .year, value: -13, to: Date()) ?? Date()
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 10) {
                        Text("Complete Your Profile")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Let's get to know you better")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    
                    // Profile Photo
                    VStack(spacing: 15) {
                        Button(action: { showImagePicker = true }) {
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.beatrooPink, lineWidth: 3)
                                    )
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 120, height: 120)
                                    
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        
                        Text("Add Profile Photo")
                            .font(.system(size: 14))
                            .foregroundColor(Color.beatrooPink)
                    }
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        // Display Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Display Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            TextField("Enter your display name", text: $displayName)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        
                        // Username
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            TextField("Choose a unique username", text: $username)
                                .textFieldStyle(CustomTextFieldStyle())
                                .autocapitalization(.none)
                        }
                        
                        // Date of Birth
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date of Birth")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Button(action: { showDatePicker.toggle() }) {
                                HStack {
                                    Text(dateFormatter.string(from: dateOfBirth))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "calendar")
                                        .foregroundColor(Color.beatrooPink)
                                }
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                            }
                            
                            if !isValidAge {
                                Text("You must be at least 13 years old")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.beatrooPink)
                            }
                        }
                        
                        // Date Picker (shown when tapped)
                        if showDatePicker {
                            DatePicker(
                                "Date of Birth",
                                selection: $dateOfBirth,
                                in: ...maximumDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(WheelDatePickerStyle())
                            .labelsHidden()
                            .colorScheme(.dark)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(12)
                        }
                        
                        // Gender
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Gender")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Menu {
                                ForEach(Gender.allCases, id: \.self) { gender in
                                    Button(gender.displayName) {
                                        selectedGender = gender
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedGender.displayName)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                            }
                            
                            // Custom Gender Field
                            if selectedGender == .custom {
                                TextField("Enter your gender", text: $customGender)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .transition(.opacity)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    // Continue Button
                    Button(action: saveProfile) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Continue")
                                .font(.system(size: 18, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isFormValid ? Color.beatrooPink : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(28)
                    .disabled(!isFormValid || isLoading)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveProfile() {
        guard var user = authManager.currentUser else { return }
        
        isLoading = true
        
        Task {
            do {
                // Upload profile photo first
                if let image = selectedImage {
                    let photoURL = try await authManager.uploadProfilePhoto(image)
                    user.photoURL = photoURL
                }
                
                // Update user data
                user.displayName = displayName
                user.username = username
                user.age = age
                user.gender = selectedGender
                if selectedGender == .custom {
                    user.customGender = customGender
                }
                
                // Save to Firestore
                try await authManager.saveUserProfile(user)
                
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            
            isLoading = false
        }
    }
}

// Custom TextField Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
            .foregroundColor(.white)
    }
}

// Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
} 