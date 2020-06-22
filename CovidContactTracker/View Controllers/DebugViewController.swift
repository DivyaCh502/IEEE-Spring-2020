//
//  DebugViewController.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/12/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import UIKit
import SwiftEx

class DebugViewController: UIViewController {

    @IBOutlet var buttons: [UIButton]!
    @IBOutlet weak var containerView: UIView!
    
    private var lastInfoListViewController: UIViewController?
    private var lastLogsViewController: UIViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar(isTransparent: false)
        buttonActions(buttons.first!)
        initNavigationBar()
    }
    
    /// Add buttons for testing
    private func initNavigationBar() {
        //        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(uploadTestReport))
    }
    
    
    @IBAction func buttonActions(_ sender: UIButton) {
        for button in buttons {
            button.isSelected = button.tag == sender.tag
        }
        switch sender.tag {
        case 0:
            guard let vc = lastInfoListViewController ?? create(InfoListViewController.self) else { return }
            loadViewController(vc, containerView)
            lastInfoListViewController = vc
        case 1:
            guard let vc = lastLogsViewController ?? create(LogsViewController.self) else { return }
            loadViewController(vc, containerView)
            lastLogsViewController = vc
        default:
            break
        }
    }
}

class LogsViewController: UIViewController {
    
    /// outlets
    @IBOutlet weak var tableView: UITableView!
    
    /// the table model
    private var table = InfiniteTableViewModel<String, LogCell>()
    
    private var items = [String]()
    
    /// Setup UI
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        table.configureCell = { indexPath, item, _, cell in
            cell.configure(item)
        }
        table.onSelect = { _, item in
        }
        table.loadItems = { [weak self] callback, failure in
            guard self != nil else { return }
            callback(DataSource.logs)
        }
        table.bindData(to: tableView)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DataSource.logCallback = { [weak self] in
            DispatchQueue.main.async {
                self?.table.loadData()
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        DataSource.logCallback = nil
    }
}

/// Cell for table in this view controller
class LogCell: UITableViewCell {
    
    /// outlets
    @IBOutlet weak var titleLabel: UILabel!
    
    /// the related item
    private var item: String!
    
    /// Setup UI
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
    }
    
    /// Update UI with given data
    ///
    /// - Parameters:
    ///   - item: the data to show in the cell
    func configure(_ item: String) {
        self.item = item
        titleLabel.text = item
    }
}
