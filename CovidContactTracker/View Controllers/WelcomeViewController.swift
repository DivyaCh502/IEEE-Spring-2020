//
//  WelcomeViewController.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/2/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import UIKit
import SwiftEx
import SwiftyJSON
import WebKit
import UIComponents

struct WelcomItem {
    let title: String
    let icon: String
    
    static func from(_ json: JSON) -> WelcomItem {
        return WelcomItem(title: json["title"].stringValue, icon: json["icon"].stringValue)
    }
}

/// Welcome screen
class WelcomeViewController: UIViewController {

    /// outlets
    @IBOutlet weak var tableHeight: NSLayoutConstraint!
    @IBOutlet weak var tableView: UITableView!
    
    /// the table model
    private var table = InfiniteTableViewModel<Any, UITableViewCell>()
    
    private var items: [Any] = []
    
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
        items = (JSON.resource(named: "welcome")?.arrayValue.map({WelcomItem.from($0)}) ?? []) + [""]
        table.preConfigure = { [weak self] indexPath, item, _ -> UITableViewCell in
            guard self != nil else { return UITableViewCell() }
            if indexPath.row == (self?.items.count ?? 0) - 1 {
                let cell = self!.tableView.cell(indexPath, ofClass: GotItButtonCell.self)
                cell.parent = self
                return cell
            }
            else {
                let isLeft = indexPath.row % 2 == 0
                let item = item as! WelcomItem
                if let cell = self!.tableView.dequeueReusableCell(withIdentifier: "WelcomeItemCell\(isLeft ? "1" : "2")", for: indexPath) as? WelcomeItemCell {
                    cell.configure(item, isLeft: isLeft, isFirst: indexPath.row == 0)
                    return cell
                }
            }
            return UITableViewCell()
        }
        table.onSelect = { _, item in
        }
        table.loadItems = { [weak self] callback, failure in
            guard self != nil else { return }
            callback(self!.items)
        }
        table.tableHeight = tableHeight
        table.bindData(to: tableView)
        
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
            AuthenticationUtil.cleanUp()
            guard let vc = create(LoginViewController.self) else { return }
            vc.callback = {
                self.pushViewController(MainViewController.self)
            }
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

/// Cell for table in this view controller
class WelcomeItemCell: ClearCell {
    
    /// outlets
    @IBOutlet weak var dashedView: DashedCellView!
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    
    /// the related item
    private var item: WelcomItem!
    
    /// Setup UI
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
    }
    
    /// Update UI with given data
    ///
    /// - Parameters:
    ///   - item: the data to show in the cell
    ///   - isLeft: true - if left item, false - else
    func configure(_ item: WelcomItem, isLeft: Bool, isFirst: Bool) {
        self.item = item
        titleLabel.text = item.title
        dashedView.isFirst = isFirst
        
        self.iconView.image = nil
        UIImage.load(item.icon) { [weak self] (image) in
            if self?.item.icon == item.icon {
                self?.iconView.image = image
            }
        }
    }
}

class GotItButtonCell: ClearCell {
    
    fileprivate var parent: WelcomeViewController!
    
    @IBAction func buttonAction(_ sender: Any) {
        parent.gotItAction(self)
    }
    
}
