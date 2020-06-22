//
//  MenuViewController.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/20/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import UIKit
import WebKit

/// Menu screen
class MenuViewController: UIViewController {

    /// outlets
    @IBOutlet weak var contactsButton: UIButton!
    
    /// Setup UI
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        contactsButton.isHidden = !AuthenticationUtil.isTester
    }
    
    @IBAction func contactsAction(_ sender: Any) {
        self.dismissViewControllerToSide(self, side: .left) {
            UIViewController.getCurrentViewController()?.pushViewController(DebugViewController.self)
        }
    }
    
    @IBAction func logoutAction(_ sender: Any) {
        self.dismissViewControllerToSide(self, side: .left) {
            let websiteDataTypes = NSSet(array: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
            let date = Date(timeIntervalSince1970: 0)
            WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes as! Set<String>, modifiedSince: date, completionHandler:{ })
            AppDelegate.tryStop()
            AuthenticationUtil.cleanUp()
            UIViewController.getNavigationController()?.popToRootViewController(animated: true)
        }
    }
    
    @IBAction func swipeLeft(_ sender: Any) {
        self.dismissViewControllerToSide(self, side: .left) {}
    }
}
