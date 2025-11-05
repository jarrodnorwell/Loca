//
//  LocaController.swift
//  Loca
//
//  Created by Jarrod Norwell on 28/10/2025.
//

import AuthenticationServices
import CoreLocation
import FirebaseAuth
import FirebaseFirestore
import MapKit
import WeatherKit
import UIKit

class LocaController : UIViewController {
    var mapView: MKMapView? = nil
    /*
     private var visualEffectView: UIVisualEffectView? = nil
     private var directionAndDistanceView: DirectionAndDistanceView? = nil
     */
    
    private var nonce: String? = nil
    
    var leftBarButtonItem: UIBarButtonItem? {
        if let _: User = auth.currentUser {
            nil
        } else {
            .init(image: .init(systemName: "person.crop.circle"), menu: .init(children: [
                UIAction(title: "Sign in with Apple", image: .init(systemName: "apple.logo")) { _ in
                    let nonce: String = .nonce()
                    self.nonce = nonce
                    
                    let appleIDProvider: ASAuthorizationAppleIDProvider = .init()
                    
                    let request: ASAuthorizationAppleIDRequest = appleIDProvider.createRequest()
                    request.nonce = .sha256(from: nonce)
                    request.requestedScopes = [.email, .fullName]
                    
                    let authorizationController: ASAuthorizationController = .init(authorizationRequests: [request])
                    authorizationController.delegate = self
                    authorizationController.presentationContextProvider = self
                    authorizationController.performRequests()
                }
            ]))
        }
    }
    
    let auth: Auth = .auth()
    let firestore: Firestore = .firestore()
    
    let manager: CLLocationManager = .init()
    
    var friendsController: FriendsController? = nil
    
    var firstLocationAfterInitialLaunch: CLLocation? = nil
    init(_ firstLocationAfterInitialLaunch: CLLocation? = nil) {
        self.firstLocationAfterInitialLaunch = firstLocationAfterInitialLaunch
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = leftBarButtonItem
        view.backgroundColor = .systemBackground
        
        mapView = .init()
        guard let mapView else {
            return
        }
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        view.addSubview(mapView)
        
        mapView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        
        // MARK: Notifications
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(forName: UIDevice.batteryLevelDidChangeNotification,
                                               object: nil,
                                               queue: .current) { notification in
            if let user: User = self.auth.currentUser {
                let document: DocumentReference = self.firestore.collection("users").document(user.uid)
                Task {
                    let me: Me = try await document.as(Me.self)
                    me.deviceInfo.batteryLevel = await UIDevice.current.batteryLevel
                    try document.setData(from: me, mergeFields: ["deviceInfo.batteryLevel"])
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIDevice.batteryStateDidChangeNotification,
                                               object: nil,
                                               queue: .current) { notification in
            if let user: User = self.auth.currentUser {
                let document: DocumentReference = self.firestore.collection("users").document(user.uid)
                Task {
                    let me: Me = try await document.as(Me.self)
                    me.deviceInfo.batteryState = await UIDevice.current.batteryState.rawValue
                    try document.setData(from: me, mergeFields: ["deviceInfo.batteryState"])
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
                                               object: nil,
                                               queue: .current) { notification in
            if let user: User = self.auth.currentUser {
                let document: DocumentReference = self.firestore.collection("users").document(user.uid)
                Task {
                    let me: Me = try await document.as(Me.self)
                    me.deviceInfo.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                    try document.setData(from: me, mergeFields: ["deviceInfo.lowPowerMode"])
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // MARK: Firestore
        if let user: User = auth.currentUser {
            manager.activityType = .fitness
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.distanceFilter = 10
            manager.headingFilter = 90
            manager.startUpdatingHeading()
            manager.startUpdatingLocation()
            
            let document: DocumentReference = firestore.collection("users").document(user.uid)
            
            friendsController = .init(auth: auth, document: document, firestore: firestore)
            guard let friendsController else {
                return
            }
            
            let viewController: UINavigationController = .init(rootViewController: friendsController)
            
            if let sheetPresentationController = viewController.sheetPresentationController {
                let custom: UISheetPresentationController.Detent = .custom { context in self.view.safeAreaInsets.top + self.view.safeAreaInsets.bottom }
                let medium: UISheetPresentationController.Detent = .medium()
                
                sheetPresentationController.delegate = self
                sheetPresentationController.detents = [custom, medium]
                sheetPresentationController.largestUndimmedDetentIdentifier = custom.identifier
                sheetPresentationController.prefersGrabberVisible = true
                if #available(iOS 26.1, *) {
                    sheetPresentationController.backgroundEffect = UIBlurEffect(style: .regular)
                }
            }
            present(viewController, animated: true) {
                friendsController.addSnapshotListener(to: document, for: user)
            }
            
            addSnapshotListener(to: document, for: user)
            
            Task {
                if let location: CLLocation = manager.location {
                    let me: Me = try await document.as(Me.self)
                    
                    let weather: Weather = try await WeatherService.shared.weather(for: location)
                    me.location.weather.day = weather.currentWeather.isDaylight
                    me.location.weather.symbolName = weather.currentWeather.symbolName
                    me.location.weather.temperature = weather.currentWeather.temperature
                    
                    try document.setData(from: me, mergeFields: [
                        "location.weather.day",
                        "location.weather.symbolName",
                        "location.weather.temperature"
                    ])
                }
            }
        }
    }
    
    func addSnapshotListener(to document: DocumentReference, for user: User) {
        document.addSnapshotListener { snapshot, error in
            guard let mapView = self.mapView, let snapshot: DocumentSnapshot = snapshot else {
                return
            }
            
            if snapshot.exists {
                Task {
                    let me: Me = try await snapshot.reference.as(Me.self)
                    let friendsMapped: [Friend] = try await me.friends.asyncMap { friend in
                        try await friend.getDocument(as: Friend.self)
                    }
                    
                    mapView.addAnnotations(for: friendsMapped)
                }
            } else {
                Task {
                    var location: Location
                    if let initialLaunchLocation = self.firstLocationAfterInitialLaunch {
                        let weather: Weather = try await WeatherService.shared.weather(for: initialLaunchLocation)
                        
                        location = .init(heading: .init(),
                                         latitude: initialLaunchLocation.coordinate.latitude,
                                         longitude: initialLaunchLocation.coordinate.longitude,
                                         speed: .init(speed: initialLaunchLocation.speed,
                                                      speedAccuracy: initialLaunchLocation.speedAccuracy),
                                         weather: .init(day: weather.currentWeather.isDaylight,
                                                        symbolName: weather.currentWeather.symbolName,
                                                        temperature: weather.currentWeather.temperature))
                    } else {
                        location = .init(heading: .init(),
                                         latitude: 0,
                                         longitude: 0,
                                         speed: .init(),
                                         weather: .init())
                    }
                    
                    let name: Name = if let displayName = user.displayName {
                        .init(firstName: displayName.components(separatedBy: " ").first ?? "",
                              lastName: displayName.components(separatedBy: " ").last ?? "")
                    } else {
                        .init(firstName: "", lastName: "")
                    }
                    
                    let photoURLString: String = if let photoURL = user.photoURL {
                        photoURL.path(percentEncoded: false)
                    } else { "" }
                    
                    let me: Me = .init(deviceInfo: .init(batteryLevel: UIDevice.current.batteryLevel,
                                                         batteryState: UIDevice.current.batteryState.rawValue,
                                                         lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled),
                                       friends: [],
                                       location: location,
                                       name: name,
                                       photoURLString: photoURLString)
                    
                    try snapshot.reference.setData(from: me, merge: true)
                }
            }
        }
    }
}

// MARK: Authentication
extension LocaController : ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce: String = nonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            
            guard let appleIDToken: Data = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                return
            }
            
            guard let idTokenString: String = .init(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }
            
            let credential: OAuthCredential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                                            rawNonce: nonce,
                                                                            fullName: appleIDCredential.fullName)
            
            let task = Task {
                try await auth.signIn(with: credential)
            }
            
            Task {
                switch await task.result {
                case .success(let result):
                    navigationItem.leftBarButtonItem = leftBarButtonItem
                    
                    manager.activityType = .fitness
                    manager.delegate = self
                    manager.desiredAccuracy = kCLLocationAccuracyBest
                    manager.distanceFilter = 10
                    manager.headingFilter = 90
                    manager.startUpdatingHeading()
                    manager.startUpdatingLocation()
                    
                    let document: DocumentReference = firestore.collection("users").document(result.user.uid)
                    
                    friendsController = .init(auth: auth, document: document, firestore: firestore)
                    guard let friendsController else {
                        return
                    }
                    friendsController.addSnapshotListener(to: document, for: result.user)
                    
                    let viewController: UINavigationController = .init(rootViewController: friendsController)
                    
                    if let sheetPresentationController = viewController.sheetPresentationController {
                        let custom: UISheetPresentationController.Detent = .custom { context in self.view.safeAreaInsets.top + self.view.safeAreaInsets.bottom  }
                        
                        sheetPresentationController.delegate = self
                        sheetPresentationController.detents = [custom, .medium()]
                        sheetPresentationController.largestUndimmedDetentIdentifier = custom.identifier
                        sheetPresentationController.prefersGrabberVisible = true
                        if #available(iOS 26.1, *) {
                            sheetPresentationController.backgroundEffect = UIBlurEffect(style: .regular)
                        }
                    }
                    present(viewController, animated: true) {
                        friendsController.addSnapshotListener(to: document, for: result.user)
                    }
                    
                    addSnapshotListener(to: document, for: result.user)
                case .failure(let error):
                    print(error.localizedDescription)
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Sign in with Apple errored: \(error)")
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let window: UIWindow = view.window {
            window
        } else {
            .init()
        }
    }
}

// MARK: Location
extension LocaController : CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        print(#function, #line, error, error.localizedDescription)
        guard let friendsController else {
            return
        }
        
        friendsController.locationManager(manager, didFailWithError: error)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard let friendsController else {
            return
        }
        
        friendsController.locationManager(manager, didUpdateHeading: newHeading)
        
        guard let user: User = auth.currentUser else {
            return
        }
        
        let document: DocumentReference = firestore.collection("users").document(user.uid)
        
        let task = Task {
            try await document.as(Me.self)
        }
        
        Task {
            switch await task.result {
            case .success(let me):
                me.location.heading = .init(magneticHeading: newHeading.magneticHeading,
                                            trueHeading: newHeading.trueHeading,
                                            headingAccuracy: newHeading.headingAccuracy,
                                            x: newHeading.x,
                                            y: newHeading.y,
                                            z: newHeading.z,
                                            timestamp: newHeading.timestamp)
                
                try document.setData(from: me, mergeFields: ["location.heading"])
            case .failure(let error):
                print(#function, #line, error, error.localizedDescription)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let friendsController else {
            return
        }
        
        friendsController.locationManager(manager, didUpdateLocations: locations)
        
        guard let user: User = auth.currentUser, let location = locations.last else {
            return
        }
        
        let document: DocumentReference = firestore.collection("users").document(user.uid)
        
        let task = Task {
            try await document.as(Me.self)
        }
        
        Task {
            switch await task.result {
            case .success(let me):
                me.location.latitude = location.coordinate.latitude
                me.location.longitude = location.coordinate.longitude
                
                me.location.speed.speed = location.speed
                me.location.speed.speedAccuracy = location.speedAccuracy
                
                try document.setData(from: me, mergeFields: [
                    "location.latitude",
                    "location.longitude",
                    "location.speed.speed",
                    "location.speed.speedAccuracy"
                ])
            case .failure(let error):
                print(#function, #line, error, error.localizedDescription)
            }
        }
    }
}

// MARK: Maps
extension LocaController : MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
        let renderer: MKPolylineRenderer = .init(overlay: overlay)
        renderer.lineWidth = 5
        renderer.strokeColor = .systemMint.withProminence(.secondary)
        return renderer
    }
}

// MARK: Sheet
extension LocaController : UISheetPresentationControllerDelegate {
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        false
    }
}
