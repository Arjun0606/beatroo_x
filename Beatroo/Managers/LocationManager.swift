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
        
        // Set initial authorization status
        authorizationStatus = locationManager.authorizationStatus
        print("LocationManager: Initialized with authorization status: \(authorizationStatus)")
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
    }
    
    func requestLocationPermission() {
        print("LocationManager: Current authorization status: \(authorizationStatus)")
        
        switch authorizationStatus {
        case .notDetermined:
            print("LocationManager: Requesting location permission...")
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            print("LocationManager: Location access denied/restricted")
            locationError = "Location access is required for discovering nearby music. Please enable it in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            print("LocationManager: Already authorized, starting location updates")
            startLocationUpdates()
        @unknown default:
            print("LocationManager: Unknown status, requesting permission...")
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    private func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("LocationManager: Cannot start location updates - not authorized")
            return
        }
        
        print("LocationManager: Starting location updates...")
        locationManager.startUpdatingLocation()
        
        // Also try to get location immediately (on background thread to avoid UI blocking)
        if CLLocationManager.locationServicesEnabled() {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.locationManager.requestLocation()
            }
        }
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    private func reverseGeocode(_ location: CLLocation) {
        print("LocationManager: Starting reverse geocoding for location: \(location.coordinate)")
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            if let error = error {
                print("LocationManager: Geocoding error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.locationError = "Failed to determine city: \(error.localizedDescription)"
                }
                return
            }
            
            guard let placemark = placemarks?.first else {
                print("LocationManager: No placemarks found")
                DispatchQueue.main.async {
                    self.locationError = "Could not determine city from location"
                }
                return
            }
            
            DispatchQueue.main.async {
                let city = placemark.locality ?? placemark.subAdministrativeArea ?? "Unknown City"
                let country = placemark.country ?? "Unknown Country"
                
                self.currentCity = city
                self.currentCountry = country
                self.locationError = nil
                
                print("LocationManager: Location updated successfully: \(city), \(country)")
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
        guard let newLocation = locations.last else { 
            print("LocationManager: No location in update")
            return 
        }
        
        print("LocationManager: Received location update: \(newLocation.coordinate)")
        
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
        print("LocationManager: Authorization status changed to: \(status)")
        
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("LocationManager: Location authorized, starting updates")
            startLocationUpdates()
        case .denied, .restricted:
            print("LocationManager: Location access denied/restricted")
            DispatchQueue.main.async {
                self.locationError = "Location access denied. Please enable it in Settings to discover nearby music."
            }
        case .notDetermined:
            print("LocationManager: Location permission not determined yet")
            break
        @unknown default:
            print("LocationManager: Unknown authorization status")
            break
        }
    }
} 