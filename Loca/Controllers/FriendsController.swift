//
//  FriendsController.swift
//  Loca
//
//  Created by Jarrod Norwell on 29/10/2025.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import MapKit
import OnboardingKit
import UIKit

class FriendsController : UIViewController {
    var dataSource: UICollectionViewDiffableDataSource<Friend, Friend>? = nil
    var snapshot: NSDiffableDataSourceSnapshot<Friend, Friend>? = nil
    
    var heading: CLHeading = .init()
    var location: CLLocation = .init()
    
    var listeners: [String : ListenerRegistration] = [:]
    
    var rightBarButtonItems: [UIBarButtonItem] {
        if let _: User = auth.currentUser {
            [
                .init(image: .init(systemName: "ellipsis"), menu: .init(children: [
                    UIAction(title: "Share Friend Code", image: .init(systemName: "arrow.up.page.on.clipboard")) { _ in
                        UIPasteboard.general.string = self.document.documentID
                        
                        let alertController: UIAlertController = .init(title: "Friend Code Copied",
                                                                       message: "Friend code has been copied to the pasteboard. Share it with a friend so they can add you to their friend list",
                                                                       preferredStyle: .alert)
                        alertController.addAction(.init(title: "Dismiss", style: .cancel))
                        self.present(alertController, animated: true)
                    }/*,
                    UIMenu(title: "Profile", image: .init(systemName: "person.text.rectangle"), children: [
                        UIAction(title: "Show Offline", image: .init(systemName: "network.slash")) { _ in
                            
                        }
                    ])*/
                ])),
                .init(image: .init(systemName: "plus"), primaryAction: .init { _ in
                    let alertController: UIAlertController = .init(title: "Add Friend",
                                                                   message: "Enter a friend code shared with you below to add them to your friend list",
                                                                   preferredStyle: .alert)
                    alertController.addAction(.init(title: "Cancel", style: .cancel))
                    alertController.addAction(.init(title: "Add Friend", style: .default) { _ in
                        guard let textFields: [UITextField] = alertController.textFields,
                              let textField: UITextField = textFields.first,
                              let uid: String = textField.text else {
                            return
                        }
                        
                        Task {
                            guard var references: [DocumentReference] = try await self.document.getDocument().data()?["friends"] as? [DocumentReference] else {
                                return
                            }
                            
                            let reference: DocumentReference = self.firestore.collection("users").document(uid)
                            self.listeners[reference.documentID] = reference.addSnapshotListener { snapshot, error in
                                guard let snapshot: DocumentSnapshot = snapshot else {
                                    return
                                }
                                
                                Task {
                                    try await self.addUpdateListener(to: try await reference.as(Friend.self), with: snapshot)
                                }
                            }
                            references.append(reference)
                            try await self.document.updateData(["friends" : references])
                        }
                    })
                    alertController.addTextField { textField in
                        textField.placeholder = self.document.documentID
                    }
                    alertController.preferredAction = alertController.actions.last
                    self.present(alertController, animated: true)
                })
            ]
        } else {
            [
                .init(image: .init(systemName: "plus"), primaryAction: .init { _ in
                    let alertController: UIAlertController = .init(title: "Add Friend",
                                                                   message: "Enter a friend code shared with you below to add them to your friend list",
                                                                   preferredStyle: .alert)
                    alertController.addAction(.init(title: "Cancel", style: .cancel))
                    alertController.addAction(.init(title: "Add Friend", style: .default) { _ in
                        guard let textFields: [UITextField] = alertController.textFields,
                              let textField: UITextField = textFields.first,
                              let uid: String = textField.text else {
                            return
                        }
                        
                        Task {
                            guard var references: [DocumentReference] = try await self.document.getDocument().data()?["friends"] as? [DocumentReference] else {
                                return
                            }
                            
                            let reference: DocumentReference = self.firestore.collection("users").document(uid)
                            self.listeners[reference.documentID] = reference.addSnapshotListener { snapshot, error in
                                guard let snapshot: DocumentSnapshot = snapshot else {
                                    return
                                }
                                
                                Task {
                                    try await self.addUpdateListener(to: try await reference.as(Friend.self), with: snapshot)
                                }
                            }
                            references.append(reference)
                            try await self.document.updateData(["friends" : references])
                        }
                    })
                    alertController.addTextField { textField in
                        textField.placeholder = UUID().uuidString
                    }
                    alertController.preferredAction = alertController.actions.last
                    self.present(alertController, animated: true)
                })
            ]
        }
    }
    
    var collectionView: UICollectionView? = nil
    
    var auth: Auth
    var document: DocumentReference
    var firestore: Firestore
    init(auth: Auth, document: DocumentReference, firestore: Firestore) {
        self.auth = auth
        self.document = document
        self.firestore = firestore
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let navigationController {
            navigationController.navigationBar.prefersLargeTitles = true
        }
        navigationItem.largeTitleDisplayMode = .inline
        navigationItem.style = .browser
        navigationItem.largeTitle = "Friends"
        navigationItem.title = navigationItem.largeTitle
        navigationItem.largeSubtitle = "Fetching friends..."
        navigationItem.subtitle = navigationItem.largeSubtitle
        navigationItem.rightBarButtonItems = rightBarButtonItems
        
        var configuration: UICollectionLayoutListConfiguration = .init(appearance: .insetGrouped)
        configuration.headerMode = .supplementary
        configuration.trailingSwipeActionsConfigurationProvider = { indexPath in
            let removeAction: UIContextualAction = .init(style: .destructive, title: nil) { action, sourceView, actionPerformed in
                Task {
                    guard let dataSource: UICollectionViewDiffableDataSource<Friend, Friend> = self.dataSource,
                          let itemIdentifier: Friend = dataSource.itemIdentifier(for: indexPath),
                          let id = itemIdentifier.id else {
                        return
                    }
                    
                    guard var references: [DocumentReference] = try await self.document.getDocument().data()?["friends"] as? [DocumentReference] else {
                        return
                    }
                    
                    if let index = self.listeners.index(forKey: id) {
                        self.listeners.values[index].remove()
                        self.listeners.remove(at: index)
                    }
                    
                    if let index = references.firstIndex(where: { $0.documentID == id }) {
                        references.remove(at: index)
                    }
                    
                    try await self.document.updateData(["friends" : references])
                    
                    actionPerformed(true)
                }
            }
            removeAction.image = .init(systemName: "trash")
            
            let showDirectionsAction: UIContextualAction = .init(style: .normal, title: nil) { action, sourceView, actionPerformed in
                func directions(_ from: CLLocation, _ to: CLLocation, with mapView: MKMapView) {
                    let request = MKDirections.Request()
                    request.source = .init(location: from, address: nil)
                    request.destination = .init(location: to, address: nil)
                    
                    MKDirections(request: request).calculate { response, error in
                        guard let response, let route = response.routes.first else {
                            return
                        }

                        mapView.addOverlay(route.polyline)
                        mapView.setVisibleMapRect(route.polyline.boundingMapRect, animated: true)
                        mapView.showsUserLocation = true
                    }
                }
                
                guard let dataSource: UICollectionViewDiffableDataSource<Friend, Friend> = self.dataSource,
                      let itemIdentifier: Friend = dataSource.itemIdentifier(for: indexPath) else {
                    return
                }
                
                guard let navigationController: UINavigationController = self.presentingViewController as? UINavigationController,
                      let locaController: LocaController = navigationController.viewControllers.first as? LocaController,
                      let mapView = locaController.mapView else {
                    return
                }
                
                directions(self.location, itemIdentifier.location.location, with: mapView)
                
                actionPerformed(true)
            }
            showDirectionsAction.backgroundColor = .systemBlue
            showDirectionsAction.image = .init(systemName: "point.bottomleft.forward.to.arrow.triangle.scurvepath")
            
            let zoomAction: UIContextualAction = .init(style: .normal, title: nil) { action, sourceView, actionPerformed in
                guard let dataSource: UICollectionViewDiffableDataSource<Friend, Friend> = self.dataSource,
                      let itemIdentifier: Friend = dataSource.itemIdentifier(for: indexPath) else {
                    return
                }
                
                guard let navigationController: UINavigationController = self.presentingViewController as? UINavigationController,
                      let locaController: LocaController = navigationController.viewControllers.first as? LocaController,
                      let mapView = locaController.mapView else {
                    return
                }
                
                mapView.setRegion(.init(center: itemIdentifier.location.coordinate,
                                        span: .init(latitudeDelta: 0.05, longitudeDelta: 0.05)),
                                  animated: true)
                
                actionPerformed(true)
            }
            zoomAction.backgroundColor = .systemBlue
            zoomAction.image = .init(systemName: "binoculars")
                
            return .init(actions: [removeAction, zoomAction])
        }
        let collectionViewLayout: UICollectionViewCompositionalLayout = .list(using: configuration)
        
        collectionView = .init(frame: .zero, collectionViewLayout: collectionViewLayout)
        guard let collectionView else {
            return
        }
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        view.addSubview(collectionView)
        
        collectionView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        
        let headerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell> = .init(elementKind: UICollectionView.elementKindSectionHeader) {
            cell, elementKind, indexPath in
            var contentConfiguration: UIListContentConfiguration = .extraProminentInsetGroupedHeader()
            if let dataSource = self.dataSource, let sectionIdentifier = dataSource.sectionIdentifier(for: indexPath.section) {
                contentConfiguration.text = sectionIdentifier.name.formatted()
                contentConfiguration.secondaryText = "\(sectionIdentifier.friends.count) friend\(sectionIdentifier.friends.count == 1 ? "" : "s") added"
                
                let batteryState: UIDevice.BatteryState = switch sectionIdentifier.deviceInfo.batteryState {
                case 0: .unknown
                case 1: .unplugged
                case 2: .charging
                case 3: .full
                default: .unknown
                }
                
                let systemName: String = switch batteryState {
                case .unknown: "battery.0percent"
                case .unplugged:
                    switch sectionIdentifier.deviceInfo.batteryLevel * 100 {
                    case 0..<25: "battery.25percent"
                    case 25..<50: "battery.50percent"
                    case 50..<75: "battery.75percent"
                    case 75...100: "battery.100percent"
                    default: "battery.0percent"
                    }
                case .charging: "battery.100percent.bolt"
                case .full: "battery.100percent"
                default: ""
                }
                
                var hierarchicalColor: UIColor = switch sectionIdentifier.deviceInfo.batteryLevel * 100 {
                case 0..<20: .systemRed
                case 20..<50: .systemOrange
                case 50...100: .systemGreen
                default: .systemRed
                }
                
                if sectionIdentifier.deviceInfo.lowPowerMode {
                    hierarchicalColor = .systemYellow
                } else if batteryState == .charging {
                    hierarchicalColor = .systemGreen
                }
                
                let imageView: UIImageView = .init(image: .init(systemName: systemName)?
                    .applyingSymbolConfiguration(.init(hierarchicalColor: hierarchicalColor))?
                    .applyingSymbolConfiguration(.init(scale: .large)))
                
                cell.accessories = [
                    .customView(configuration: .init(customView: imageView, placement: .trailing(displayed: .always)))
                ]
            }
            cell.contentConfiguration = contentConfiguration
        }
        
        let cellRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, Friend> = .init { cell, indexPath, itemIdentifier in
            func cardinal(to friend: Friend) -> String {
                let bearing: Double = self.location.coordinate.bearing(to: .init(latitude: friend.location.latitude,
                                                                                              longitude: friend.location.longitude))
                let deviceHeading: CLLocationDirection = if self.heading.trueHeading >= 0 {
                    self.heading.trueHeading
                } else {
                    self.heading.magneticHeading
                }
                
                let relativeBearing: Double = (bearing - deviceHeading).normalizedDegrees
                return self.location.coordinate.cardinal(from: relativeBearing)
            }
            
            var contentConfiguration: UIListContentConfiguration = .cell()
            let mapPoint1: MKMapPoint = .init(self.location.coordinate)
            let mapPoint2: MKMapPoint = .init(itemIdentifier.location.coordinate)
            
            let distanceFormatter: MeasurementFormatter = .init()
            distanceFormatter.locale = Locale.current
            distanceFormatter.numberFormatter.maximumFractionDigits = 1
            distanceFormatter.unitOptions = .naturalScale.union(.providedUnit)
            
            let speedFormatter: MeasurementFormatter = .init()
            speedFormatter.locale = Locale.current
            speedFormatter.numberFormatter.maximumFractionDigits = 1
            speedFormatter.unitOptions = .naturalScale.union(.providedUnit)
            
            let weatherFormatter: MeasurementFormatter = .init()
            weatherFormatter.locale = Locale.current
            weatherFormatter.numberFormatter.maximumFractionDigits = 1
            weatherFormatter.unitOptions = .naturalScale.union(.providedUnit)
            
            let distance: CLLocationDistance = mapPoint1.distance(to: mapPoint2)
            let speed: CLLocationSpeed = itemIdentifier.location.speed.speed
            
            let distanceMeasurement: Measurement = .init(value: distance, unit: UnitLength.meters)
            let speedMeasurement: Measurement = .init(value: speed, unit: UnitSpeed.metersPerSecond)
            let weatherMeasurement: Measurement = itemIdentifier.location.weather.temperature
            
            contentConfiguration.text = "\(distanceFormatter.string(from: distanceMeasurement)) away"
            contentConfiguration.secondaryText = "\(cardinal(to: itemIdentifier)) • \(speedFormatter.string(from: speedMeasurement)) • \(weatherFormatter.string(from: weatherMeasurement))"
            cell.contentConfiguration = contentConfiguration
            
            let imageView: UIImageView = .init(image: .init(systemName: itemIdentifier.location.weather.symbolName.appending(".fill"))?
                .applyingSymbolConfiguration(.init(hierarchicalColor: .label))?
                .applyingSymbolConfiguration(.init(scale: .large)))
            
            cell.accessories = [
                .customView(configuration: .init(customView: imageView, placement: .trailing(displayed: .always)))
            ]
        }
        
        dataSource = .init(collectionView: collectionView) { collectionView, indexPath, itemIdentifier in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: itemIdentifier)
        }
        guard let dataSource else {
            return
        }
        
        dataSource.supplementaryViewProvider = { collectionView, elementKind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
        
        snapshot = .init()
    }
    
    func addSnapshotListener(to reference: DocumentReference, for user: User) {
        document.addSnapshotListener { snapshot, error in
            guard let dataSource: UICollectionViewDiffableDataSource<Friend, Friend> = self.dataSource else {
                return
            }
            
            if let snapshot {
                self.document = snapshot.reference
            }
            
            Task {
                let me: Me = try await reference.as(Me.self)
                let friendsMapped: [Friend] = try await me.friends.asyncMap { reference in
                    let friend: Friend = try await reference.as(Friend.self)
                    if let index = self.listeners.index(forKey: reference.documentID) {
                        self.listeners.values[index].remove()
                        self.listeners.remove(at: index)
                    }
                    
                    self.listeners[reference.documentID] = reference.addSnapshotListener { snapshot, error in
                        guard let snapshot: DocumentSnapshot = snapshot else {
                            return
                        }
                        
                        Task {
                            try await self.addUpdateListener(to: friend, with: snapshot)
                        }
                    }
                    
                    return friend
                }
                
                let subtitleString: String = if friendsMapped.count == 0 {
                    "Add a friend"
                } else {
                    "\(friendsMapped.count) friend\(friendsMapped.count == 1 ? "" : "s") added"
                }
                
                self.navigationItem.largeSubtitle = subtitleString
                self.navigationItem.subtitle = self.navigationItem.largeSubtitle
                
                guard var snapshot: NSDiffableDataSourceSnapshot<Friend, Friend> = self.snapshot else {
                    return
                }
                snapshot.appendSections(friendsMapped)
                snapshot.sectionIdentifiers.forEach { sectionIdentifier in
                    snapshot.appendItems(friendsMapped.filter { friend in friend == sectionIdentifier }, toSection: sectionIdentifier)
                }
                await dataSource.apply(snapshot)
            }
        }
    }
    
    func addUpdateListener(to friend: Friend, with documentSnapshot: DocumentSnapshot) async throws {
        guard let dataSource, let indexPath: IndexPath = dataSource.indexPath(for: friend),
              let item: Friend = dataSource.itemIdentifier(for: indexPath),
            let section: Friend = dataSource.sectionIdentifier(for: indexPath.section) else {
            return
        }
        
        let new: Friend = try documentSnapshot.data(as: Friend.self)
        item.deviceInfo = new.deviceInfo
        item.friends = new.friends
        item.location = new.location
        
        var snapshot = dataSource.snapshot()
        snapshot.reloadItems([item])
        snapshot.reloadSections([section])
        await dataSource.apply(snapshot)
    }
}

extension FriendsController : UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

// MARK: Location
extension FriendsController {
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {}
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location: CLLocation = locations.last else {
            return
        }
        
        self.location = location
    }
}
