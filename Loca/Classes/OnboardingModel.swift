//
//  OnboardingModel.swift
//  Loca
//
//  Created by Jarrod Norwell on 31/10/2025.
//

import CoreLocation
import OnboardingKit
import SwiftUI
import UIKit

typealias OBButtonConfiguration = OnboardingController.Onboarding.Button.Configuration
class OnboardingModel : NSObject {
    var locationAccess: LocationAccess = .init()
    
    var controller: UIViewController? = nil
    var result: Bool = false
    
    func location(controller: UIViewController) async {
        let buttons: [OBButtonConfiguration] = [
            OBButtonConfiguration(text: "Continue") { button, controller in
                self.controller = controller
                
                self.locationAccess.manager.delegate = self
                self.locationAccess.authorise()
                
                button.configuration?.title = "Setting up..."
            }
        ]
        
        let image: UIImage? = .init(systemName: "location.fill.viewfinder")?
            .applyingSymbolConfiguration(.init(hierarchicalColor: .systemBackground))
        let text: String = "Location"
        let secondaryText: String = "Loca requires access to Location to provide locations of friends in relation to yourself based on your current location"
        let tertiaryText: String = "You can change this option later in the Settings app"
        
        let viewController: OnboardingController = .init(configuration: .init(buttons: buttons,
                                                                              colours: Color.vibrantBlues,
                                                                              image: image,
                                                                              text: text,
                                                                              secondaryText: secondaryText,
                                                                              tertiaryText: tertiaryText))
        viewController.modalPresentationStyle = .fullScreen
        controller.present(viewController, animated: true)
    }
    
    func settings(controller: UIViewController) async {
        let buttons: [OBButtonConfiguration] = [
            OBButtonConfiguration(text: "Open Settings") { button, controller in
                guard let url: URL = .init(string: UIApplication.openSettingsURLString),
                      UIApplication.shared.canOpenURL(url) else {
                    return
                }
                
                UIApplication.shared.open(url)
            }
        ]
        
        let image: UIImage? = .init(systemName: "gearshape.fill")
        let text: String = "Access Denied"
        let secondaryText: String = "Access to Location has been denied and Loca cannot function without it. Please go to the Settings app to allow access"
        
        let viewController: OnboardingController = .init(configuration: .init(buttons: buttons,
                                                                              colours: Color.vibrantOranges,
                                                                              image: image,
                                                                              text: text,
                                                                              secondaryText: secondaryText))
        viewController.modalPresentationStyle = .fullScreen
        controller.present(viewController, animated: true)
    }
}

extension OnboardingModel : CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        result = manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse
        
        UserDefaults.standard.set(result, forKey: "loca.1.0.locationAccessGranted")
        UserDefaults.standard.set(true, forKey: "loca.1.0.onboardingComplete")
        
        manager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        print(#function, #line, error, error.localizedDescription)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let controller, let location: CLLocation = locations.last else {
            return
        }
        
        if result {
            let viewController: UINavigationController = .init(rootViewController: LocaController(location))
            viewController.modalPresentationStyle = .fullScreen
            controller.present(viewController, animated: true)
        } else {
            Task {
                await settings(controller: controller)
            }
        }
    }
}
