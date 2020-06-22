//
//  WelcomeViewController2.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/11/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import UIKit

class WelcomeViewController2: UIViewController {

    /// Setup UI
    override func viewDidLoad() {
        super.viewDidLoad()
        
        DataSource.callback401 = {
            AuthenticationUtil.cleanUp()
            if UIApplication.shared.applicationState == .active {
                DispatchQueue.main.async {
                    UIViewController.getNavigationController()?.popToRootViewController(animated: true)
                }
            }
        }
        
        // Move directly to main screen if authenticated
        if AuthenticationUtil.isAuthenticated() {
            if let vc = create(MainViewController.self) {
                navigationController?.pushViewController(vc, animated: false)
            }
        }
    }
    
    /// Remove navigation bar
    /// - Parameter animated: the animation flag
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    /// "Got it" button action handler
    ///
    /// - parameter sender: the button
    @IBAction func gotItAction(_ sender: Any) {
        if AuthenticationUtil.isAuthenticated() {
            pushViewController(MainViewController.self)
        }
        else {
            guard let vc = create(LoginViewController.self) else { return }
            vc.callback = {
                self.pushViewController(MainViewController.self)
            }
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

}
