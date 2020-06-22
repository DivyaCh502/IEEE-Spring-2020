//
//  MainViewController.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/2/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import UIKit
import SwiftEx
import CoreBluetooth
import UIComponents
import TCNClient

enum CBAuthState {
    case unknown, denied, allowed
    
    func toStatus() -> CBManagerState {
        switch self {
        case .unknown:
            return .unknown
        case .denied:
            return .unauthorized
        case .allowed:
            return .poweredOn
        }
    }
}

/// The main view
class MainViewController: UIViewController, CBCentralManagerDelegate {
    
    /// outlets
    @IBOutlet weak var mainView: UIView!
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var connectButton: CustomButton!
    @IBOutlet weak var circleView: CircleAnimatedView!
    
    /// Core Bluetooth manager
    private var manager: CBCentralManager!
    /// bluetooth status
    private var status: CBManagerState!
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }
    
    private var timer: Timer?
    
    /// Setup UI
    override func viewDidLoad() {
        super.viewDidLoad()
        connectButton.isHidden = true
        
        self.view.backgroundColor = UIColor.lightGray
        updateUI()
        NotificationCenter.add(observer: self, selector: #selector(updateAnimations), name: ApplicationEvent.active)
        NotificationCenter.add(observer: self, selector: #selector(removeAnimations), name: ApplicationEvent.resignActive)
    }
    
    @objc func updateAnimations() {
        circleView.updateAnimations()
    }
    @objc func removeAnimations() {
        circleView.removeAnimations()
    }
    
    /// Remove navigation bar
    /// - Parameter animated: the animation flag
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        mainView.roundCorners(corners: [.topLeft, .topRight], radius: 20)
        setupNavigationBar(isTransparent: true)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    /// Start bluetooth service when first launched
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        manager = CBCentralManager()
        manager.delegate = self
        checkStateAndStartIfNeeded()
        AppDelegate.requestUserNotificationAuthorization()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true, block: { (_) in
            self.updateUIStatus()
        })
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        timer = nil
    }
    
    /// Check state of the Bluetooth and start descovery if needed
    private func checkStateAndStartIfNeeded() {
        if (status == .poweredOn || status == .unknown) {
            AppDelegate.tryStartTCN()
        }
    }
    
    /// Update UI
    private func updateUI() {
        var state: CBAuthState!
        if #available(iOS 13.1, *) {
            state = CBManager.authorization.toState()
        } else {
            state = CBPeripheralManager.authorizationStatus().toState()
        }
        if self.status == nil || state == CBAuthState.denied { // If denied, then need to show it
            status = state.toStatus()
        }
        
        updateUIStatus()
        if let title = status.getTitle() {
            titleLabel.text = title
        }
        if let subtitle = status.getSubtitle() {
            subtitleLabel.text = subtitle
        }
        if let color = status.getColor() {
            view.backgroundColor = color
        }
        if let image = status.getIcon() {
            iconView.image = image
        }
        connectButton.isHidden = self.status != .poweredOff
        if self.status == .poweredOn {
            connectButton.isHidden = false
            let shouldScanning = UserDefaults.shouldStartBluetooth
            connectButton.setTitle((shouldScanning ? "Stop tracing" : "Start tracing").uppercased(), for: .normal)
            titleLabel.text = shouldScanning ? "Detecting devices near you" : "Back on campus?\n"
            if !shouldScanning {
                view.backgroundColor = CBManagerState.poweredOff.getColor()
                iconView.image = CBManagerState.poweredOff.getIcon()
            }
        }
        else { // BLE is off
            connectButton.setTitle("Start tracing".uppercased(), for: .normal)
            circleView.tryUpdateAnimations()
        }
        subtitleLabel.isHidden = !connectButton.isHidden
        circleView.isHidden = self.status == .unsupported
        
        self.navigationItem.setHidesBackButton(true, animated: false)
        navigationItem.leftBarButtonItems = [UIBarButtonItem(image: #imageLiteral(resourceName: "menu"), style: .plain, target: self, action: #selector(menuButtonAction(_:)))]
    }
    
    /// Update status label
    private func updateUIStatus() {
        if let statusInfo = status.getStatus() {
            if self.status == CBManagerState.poweredOn {
                if let date = AppDelegate.lastContactTraceDate {
                    statusLabel.text = statusInfo + "\n" + dateFormatter.string(from: date).uppercased()
                }
                else {
                    statusLabel.text = ""
                }
                if !UserDefaults.shouldStartBluetooth {
                    statusLabel.text = "Tracing is off".uppercased()
                }
            }
            else {
                statusLabel.text = statusInfo
            }
        }
    }
    
    /// "Menu" button action handler
    ///
    /// - parameter sender: the button
    @IBAction func menuButtonAction(_ sender: Any) {
        guard let vc = create(MenuViewController.self) else { return }
        showViewControllerFromSide(vc, inContainer: self.view, bounds: self.view.bounds, side: .left, nil)
    }
    
    /// "?" button action handler
    ///
    /// - parameter sender: the button
    @IBAction func questionButtonAction(_ sender: Any) {
        navigationController?.popToRootViewController(animated: true)
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.status = central.state
        switch central.state {
        case .poweredOn:
            print("centralManagerDidUpdateState: Bluetooth is On.")
        case .poweredOff:
            print("centralManagerDidUpdateState: Bluetooth is Off.")
        case .resetting:
            print("centralManagerDidUpdateState: .resetting")
        case .unauthorized:
            print("centralManagerDidUpdateState: .unauthorized")
        case .unsupported:
            print("centralManagerDidUpdateState: .unsupported")
        case .unknown:
            print("centralManagerDidUpdateState: .unknown")
        default:
            print("centralManagerDidUpdateState: -")
        }
        DispatchQueue.main.async {
            self.updateUI()
        }
        checkStateAndStartIfNeeded()
    }
    
    /// "Connect.." button action handler
    ///
    /// - parameter sender: the button
    @IBAction func connectAction(_ sender: Any) {
        if self.status == .poweredOn {
            UserDefaults.shouldStartBluetooth = !UserDefaults.shouldStartBluetooth
            if UserDefaults.shouldStartBluetooth {
                AppDelegate.tryStartTCN()
            }
            else {
                AppDelegate.tryStop()
            }
            updateUI()
        }
        else {
            let vc = UIAlertController(title: NSLocalizedString("Turn on Bluetooth", comment: ""), message: "Turn on Bluetooth in Settings app or in control center.", preferredStyle: .alert)
            vc.addAction(UIAlertAction(title: NSLocalizedString("Open Settings App", comment: ""), style: .default, handler: { _ in
                UIApplication.openBluetoothSettings()
            }))
            vc.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { _ in
            }))
            UIApplication.shared.topViewController?.present(vc, animated: true, completion: nil)
        }
    }
}

extension UIView {
    
    /// Rounds just the specified corners
    ///
    /// - Parameters:
    ///   - corners: corners to round
    ///   - radius: the radius
    func roundCorners(corners: UIRectCorner, radius: CGFloat) {
        let bounds = CGRect(origin: .zero, size: CGSize(width: UIScreen.main.bounds.width, height: self.bounds.height))
        let maskPath = UIBezierPath(roundedRect: bounds,
                                    byRoundingCorners: corners,
                                    cornerRadii: CGSize(width: radius, height: radius))
        
        let shape = CAShapeLayer()
        shape.path = maskPath.cgPath
        layer.mask = shape
    }
}

extension CBManagerState {
    
    func getTitle() -> String? {
        switch self {
        case .poweredOn:
            return "Bluetooth is ON and detecting devices near you"
        case .poweredOff:
            return "Back on campus?\n"
        case .unauthorized, .unknown:
            return "Please connect the app"
        case .resetting:
            return nil
        case .unsupported:
            return "Bluetooth is not supported"
        default:
            return nil
        }
    }
    
    func getSubtitle() -> String? {
        switch self {
        case .poweredOn:
            return "Thanks for your participation"
        case .poweredOff, .unknown, .unauthorized:
            return "Turn on Bluetooth permissions for HutchTrace in Settings"
        case .resetting:
            return nil
        case .unsupported:
            return "Your device does not have bluetooth chip"
        default:
            return nil
        }
    }
    
    func getColor() -> UIColor? {
        switch self {
        case .poweredOn:
            return UIColor(0x5cb4b9)
        case .poweredOff, .unauthorized:
            return UIColor(0xe16e63)
        case .resetting:
            return nil
        case .unsupported, .unknown:
            return .lightGray
        default:
            return nil
        }
    }
    
    func getIcon() -> UIImage? {
        switch self {
        case .poweredOn:
            return #imageLiteral(resourceName: "status1")
        case .poweredOff, .unauthorized, .unsupported, .unknown:
            return #imageLiteral(resourceName: "status0")
        default:
            return nil
        }
    }
    
    func getStatus() -> String? {
        switch self {
        case .poweredOn:
            return "LAST CONTACT TRACE"
        case .poweredOff, .unknown:
            return "Tracing is OFF".uppercased()
        case .unsupported:
            return "Bluetooth is unsupported".uppercased()
        case .unauthorized:
            return "Disconnected".uppercased()
        default:
            return nil
        }
    }
}

@available(iOS 13.0, *)
extension CBManagerAuthorization {
    
    func toState() -> CBAuthState {
        switch self {
        case .notDetermined:
            return .unknown
        case .restricted, .denied:
            return .denied
        case .allowedAlways:
            return .allowed
        @unknown default:
            return .unknown
        }
    }
}

extension CBPeripheralManagerAuthorizationStatus {
    
    func toState() -> CBAuthState {
        switch self {
        case .notDetermined:
            return .unknown
        case .restricted, .denied:
            return .denied
        case .authorized:
            return .allowed
        }
    }
}
