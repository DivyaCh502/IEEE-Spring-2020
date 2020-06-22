//
//  LoginViewController.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/6/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import UIKit
import WebKit
import SwiftEx
import RxSwift

/// Login screen
class LoginViewController: UIViewController, WKNavigationDelegate {

    /// outlets
    @IBOutlet weak var webView: WKWebView!
    
    // success callback
    var callback: (()->())?
    
    /// Setup UI
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Custom code usage
        webView.navigationDelegate = self
        loadData()
    }
    
    // MARK: - Manual API calls
    
    /// Load data
    private func loadData() {
        let url = URL(string: Configuration.cognitoLoginUrl)!
        webView.load(URLRequest(url: url))
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "app"
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let error = error as NSError
        if let url = error.userInfo["NSErrorFailingURLStringKey"] as? String {
            let a = url.split(separator: "?")
            if a.count > 0 {
                let c = a[a.count-1].split(separator: "=")
                if c.count > 0 && c[0] == "code" {
                    let code = String(c[c.count-1])
                    self.processAuthCode(code)
                    
                    return
                }
            }
        }
        self.dismiss(animated: true) {
            self.showAlert(NSLocalizedString("Error", comment: "Error"), error.localizedDescription)
        }
    }
    
    private func processAuthCode(_ code: String) {
        DispatchQueue.main.async {
            DataSource.getToken(by: code)
                .addActivityIndicator(on: UIViewController.getCurrentViewController() ?? self)
                .flatMap({ (value) -> Observable<UserPostResponse> in
                    
                    // POST /user
                    return DataSource.postUser(cognitoId: AuthenticationUtil.cognitoId, email: AuthenticationUtil.cognitoEmail, deviceToken: AppDelegate.deviceToken)
                })
                .do(onNext: { (user) in
                    AuthenticationUtil.user = user
                })
                .subscribe(onNext: { [weak self] value in
                    guard self != nil else { return }
                    // Close Login screen
                    let callback = self?.callback
                    self?.dismiss(animated: true) {
//                        callback?()
                    }
                    callback?()
                }, onError: { error in
                    print(error)
                    showError(errorMessage: error.localizedDescription)
                }).disposed(by: self.rx.disposeBag)
        }
    }
}
