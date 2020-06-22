//
//  InfoListViewController.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/4/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import UIKit
import SwiftEx
import CoreData
import os.log

/// List of devices and alerts
class InfoListViewController: UIViewController, NSFetchedResultsControllerDelegate, UITableViewDelegate, UITableViewDataSource {

    /// outlets
    @IBOutlet weak var tableView: UITableView!
    
    private var devices = [TemporaryContactNumber]()
    
    private var controller: NSFetchedResultsController<TemporaryContactNumber>?
    
    /// Setup UI
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Contact Alerts"
        
        tableView.delegate = self
        tableView.dataSource = self
        
        self.tableView.refreshControl = UIRefreshControl()
        self.tableView.refreshControl?.addTarget(self, action: #selector(refreshSignedReports), for: .valueChanged)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        requestDataAndReload()
    }
    
    /// Upload report action
    @objc func uploadTestReport() {
        let report = try! PeriodicCheckUtil.shared.generateReport()
        DataSource.upload(report: report)
            .addActivityIndicator(on: UIViewController.getCurrentViewController() ?? self)
            .subscribe(onNext: { [weak self] value in
                self?.showAlert("Report uploaded", "Report has been uploaded to the server.")
                return
            }, onError: { _ in
        }).disposed(by: rx.disposeBag)
    }
    
    private func requestDataAndReload(callback: (()->())? = nil) {
        self.loadData()
        DataSource.logs.removeAll()
        PeriodicCheckUtil.check()
            .subscribe(onNext: { [weak self] (success, user) in
                self?.loadData()
                DispatchQueue.main.async {
                    self?.showAlert("GET /user response", user?.toString() ?? "<user is not authenticated>")
                }
                callback?()
                return
            }, onError: { [weak self] _ in
                self?.loadData()
                callback?()
            }).disposed(by: rx.disposeBag)
    }
     
    /// Load data
    private func loadData() {
        PersistentContainer.shared.loadContacts { [weak self] (controller, error) in
            if let error = error {
                showError(errorMessage: error.localizedDescription)
                return
            }
            self?.controller = controller
            self?.tableView.reloadData()
        }
    }
    
    @objc private func refreshSignedReports(_ sender: Any) {
        requestDataAndReload {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.tableView.refreshControl?.endRefreshing()
            }
        }
    }
    
    // MARK: - UITableViewDelegate, UITableViewDataSource
    
    /**
     The number of rows
     
     - parameter tableView: the tableView
     - parameter section:   the section index
     
     - returns: the number of items
     */
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return controller?.fetchedObjects?.count ?? 0
    }
    
    /// Get section title
    ///
    /// - Parameters:
    ///   - tableView: the tableView
    ///   - section: the section index
    /// - Returns: the title
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Discovered TCNs"
    }
    
    // MARK: - Table methods
    
    /**
     Get cell for given indexPath
     
     - parameter tableView: the tableView
     - parameter indexPath: the indexPath
     
     - returns: cell
     */
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "DeviceInfoCell", for: indexPath) as! DeviceInfoCell
        let item = controller!.object(at: indexPath)
        cell.configure(item)
        return cell
    }
}

/// Cell for table in this view controller
class DeviceInfoCell: ClearCell {
    
    /// outlets
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!
    
    /// the related item
    private var item: TemporaryContactNumber!
    
    static var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.doesRelativeDateFormatting = true
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        return dateFormatter
    }()
    
    static var durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    /// Setup UI
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
    }
    
    /// Update UI with given data
    ///
    /// - Parameters:
    ///   - item: the data to show in the cell
    ///   - isSelected: true - if selected
    func configure(_ item: TemporaryContactNumber) {
        self.item = item
        if let foundDate = item.foundDate,
            let lastSeenDate = item.lastSeenDate {
            var string = [
                "First seen: \(DeviceInfoCell.dateFormatter.string(from: foundDate))",
                "Last seen: \(DeviceInfoCell.dateFormatter.string(from: lastSeenDate))"
                ].joined(separator: "\n")
            if let closestEstimatedDistanceMeters = item.closestEstimatedDistanceMeters?.doubleValue {
                if closestEstimatedDistanceMeters >= 0 {
                    string += "\nDistance: " + String(format: "%.1f meters", closestEstimatedDistanceMeters)
                }
                else {
                    string += "\nDistance: unknown"
                }
            }
            self.infoLabel?.text = string
        }
        idLabel.text = item.bytes?.base64EncodedString()
        
        if item.wasPotentiallyInfectious {
            self.contentView.backgroundColor = UIColor.systemRed
        }
        else {
            if #available(iOS 13.0, *) {
                self.contentView.backgroundColor = UIColor.systemBackground
            } else {
                self.contentView.backgroundColor = UIColor.white
            }
        }
    }
}

