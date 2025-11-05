//
//  SceneDelegate.swift
//  Loca
//
//  Created by Jarrod Norwell on 28/10/2025.
//

import Firebase
import FirebaseAuth
import OnboardingKit
import SwiftUI
import UIKit

class AppAttestProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        AppAttestProvider(app: app)
    }
}

class SceneDelegate : UIResponder, UIWindowSceneDelegate {
    var window: UIWindow? = nil
    
    var onboardingModel: OnboardingModel = .init()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        let appAttestProviderFactory: AppAttestProviderFactory = .init()
        AppCheck.setAppCheckProviderFactory(appAttestProviderFactory)
        
        FirebaseApp.configure()
        
        onboardingModel.locationAccess.checkAuthorisationStatus()
        UserDefaults.standard.set(onboardingModel.locationAccess.authorised, forKey: "loca.1.0.locationAccessGranted")
        
        let locationAccessGranted: Bool = UserDefaults.standard.bool(forKey: "loca.1.0.locationAccessGranted")
        let onboardingComplete: Bool = UserDefaults.standard.bool(forKey: "loca.1.0.onboardingComplete")
        
        guard let windowScene = (scene as? UIWindowScene) else {
            return
        }
        
        window = .init(windowScene: windowScene)
        guard let window else {
            return
        }
        window.rootViewController = if locationAccessGranted && onboardingComplete {
            UINavigationController(rootViewController: LocaController())
        } else {
            controller(locationAccessGranted, onboardingComplete)
        }
        window.tintColor = .systemMint
        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {}

    func sceneDidBecomeActive(_ scene: UIScene) {}

    func sceneWillResignActive(_ scene: UIScene) {}

    func sceneWillEnterForeground(_ scene: UIScene) {}

    func sceneDidEnterBackground(_ scene: UIScene) {}
    
    func controller(_ locationAccessGranted: Bool, _ onboardingComplete: Bool) -> UIViewController {
        if !locationAccessGranted && onboardingComplete {
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
            
            return viewController
        } else {
            let buttons: [OBButtonConfiguration] = [
                OBButtonConfiguration(text: "Continue") { button, controller in
                    await self.onboardingModel.location(controller: controller)
                }
            ]
            
            let image: UIImage? = .init(systemName: "globe.desk.fill")
            let text: String = "Loca"
            let secondaryText: String = "Browse a map of your friends"
            
            let viewController: OnboardingController = .init(configuration: .init(buttons: buttons,
                                                                                  colours: Color.vibrantMints,
                                                                                  image: image,
                                                                                  text: text,
                                                                                  secondaryText: secondaryText))
            
            return viewController
        }
    }
}
