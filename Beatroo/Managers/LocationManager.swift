import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentCity: String?
    @Published var currentCountry: String?
    @Published var locationError: String?
    
    private let radiusMeters: Double = 35.0 // 35 meter radius
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
    }
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationError = "Location access is required for discovering nearby music. Please enable it in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        @unknown default:
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    private func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self, let placemark = placemarks?.first else {
                print("Geocoding error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                self.currentCity = placemark.locality
                self.currentCountry = placemark.country
                print("Location updated: \(self.currentCity ?? "Unknown"), \(self.currentCountry ?? "Unknown")")
            }
        }
    }
    
    // MARK: - Distance Calculations
    
    func isUserWithinRadius(_ userLocation: GeoPoint) -> Bool {
        guard let currentLocation = location else { return false }
        
        let userCLLocation = CLLocation(
            latitude: userLocation.latitude,
            longitude: userLocation.longitude
        )
        
        let distance = currentLocation.distance(from: userCLLocation)
        return distance <= radiusMeters
    }
    
    func calculateDistance(to userLocation: GeoPoint) -> Double? {
        guard let currentLocation = location else { return nil }
        
        let userCLLocation = CLLocation(
            latitude: userLocation.latitude,
            longitude: userLocation.longitude
        )
        
        return currentLocation.distance(from: userCLLocation)
    }
    
    func getUsersWithinRadius(_ users: [NearbyUser]) -> [NearbyUser] {
        guard let currentLocation = location else { return [] }
        
        return users.compactMap { user in
            let userCLLocation = CLLocation(
                latitude: user.location.latitude,
                longitude: user.location.longitude
            )
            
            let distance = currentLocation.distance(from: userCLLocation)
            
            if distance <= radiusMeters {
                var updatedUser = user
                updatedUser = NearbyUser(
                    id: user.id,
                    username: user.username,
                    displayName: user.displayName,
                    profilePhotoURL: user.profilePhotoURL,
                    location: user.location,
                    currentTrack: user.currentTrack,
                    lastSeen: user.lastSeen,
                    distance: distance
                )
                return updatedUser
            }
            return nil
        }.sorted { ($0.distance ?? 0) < ($1.distance ?? 0) }
    }
    
    var currentGeoPoint: GeoPoint? {
        guard let location = location else { return nil }
        return GeoPoint(coordinate: location.coordinate)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        DispatchQueue.main.async {
            self.location = newLocation
            self.locationError = nil
        }
        
        // Update city/country info
        reverseGeocode(newLocation)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = "Failed to get location: \(error.localizedDescription)"
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            locationError = "Location access denied. Please enable it in Settings to discover nearby music."
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
} 