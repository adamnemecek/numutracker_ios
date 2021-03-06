//
//  AllReleasesTableViewController.swift
//  Numu Tracker
//
//  Created by Bradley Root on 10/29/16.
//  Copyright © 2016 Numu Tracker. All rights reserved.
//

import UIKit
import Crashlytics

let defaults = UserDefaults.standard

extension String {
    static let logged = "logged"
    static let newReleased = "newReleased"
    static let newAnnouncements = "newAnnouncements"
    static let moreReleases = "moreReleases"
    static let username = "username"
    static let password = "password"
}

extension UserDefaults {
    var logged: Bool {
        get {
            return bool(forKey: .logged)
        }
        set {
            set(newValue, forKey: .logged)
        }
    }

    var newReleased: Bool {
        get {
            return bool(forKey: .newReleased)
        }
        set {
            set(newValue, forKey: .newReleased)
        }
    }

    var newAnnouncements: Bool {
        get {
            return bool(forKey: .newAnnouncements)
        }
        set {
            set(newValue, forKey: .newAnnouncements)
        }
    }

    var moreReleases: Bool {
        get {
            return bool(forKey: .moreReleases)
        }
        set {
            set(newValue, forKey: .moreReleases)
        }
    }

    var username: String? {
        get {
            return string(forKey: .username)
        }
        set {
            if let v = newValue {
                set(v, forKey: .username)
            }
            else {
                removeObject(forKey: .username)
            }
        }
    }

    var password: String? {
        get {
            return string(forKey: .password)
        }
        set {
            if let v = newValue {
                set(v, forKey: .password)
            }
            else {
                removeObject(forKey: .password)
            }
        }
    }
}

extension Notification.Name {
    static let LoggedIn = Notification.Name(rawValue: "com.numutracker.loggedIn")
    static let LoggedOut = Notification.Name(rawValue: "com.numutracker.loggedOut")
    static let UpdatedArtists = Notification.Name(rawValue: "com.numutracker.artistsImported")
    static let ClosedLogRegPrompt = Notification.Name(rawValue: "com.numutracker.closedLogRegPrompt")
}


class AllReleasesTableViewController: UITableViewController {

    var lastSelectedArtistId: String = ""
    var lastSelectedArtistName: String = ""
    var selectedIndexPath : IndexPath?
    var releases: [ReleaseItem] = []
    var viewName: String = ""
    var releaseData: ReleaseData! {
        didSet {
            if releaseData.totalPages == "0" {
                DispatchQueue.main.async(execute: {
                    self.tableView.tableHeaderView = self.noResultsFooterView
                    self.tableView.tableFooterView = UIView()
                    if self.slideType == 3 {
                        self.noResultsLabel.text = "After you've followed some artists, any releases (upcoming or past) added to the system will show up here.\n\nCheck back later."
                    } else if self.slideType == 2 {
                        self.noResultsLabel.text = "Any upcoming releases will appear here."
                    } else {
                        self.noResultsLabel.text = "No results.\n\nHave you followed some artists?\n\nPull to refresh when you have."
                    }
                })
            } else {
                DispatchQueue.main.async(execute: {
                    self.tableView.tableHeaderView = nil
                })
            }
        }
    }
    var isLoading: Bool = false
    var viewType: Int = 1
    var slideType: Int = 0

    @IBOutlet var footerView: UIView!
    @IBOutlet var noResultsFooterView: UIView!
    @IBOutlet weak var noResultsLabel: UILabel!

    @IBOutlet weak var releasesSegmentedControl: UISegmentedControl!


    @IBAction func changeSlide(_ sender: UISegmentedControl) {

        let segment = sender.selectedSegmentIndex
        self.slideType = segment
        self.tableView.tableFooterView = self.footerView
        self.selectedIndexPath = nil
        releases.removeAll()
        tableView.reloadData()
        DispatchQueue.global(qos: .background).async(execute: {
            self.loadFirstReleases()
            DispatchQueue.main.async(execute: {
                self.tableView.reloadData()
                self.tableView.tableFooterView = UIView()
            })
        })
    }

    func loadFirstReleases() {
        self.isLoading = true
        JSONClient.sharedClient.getReleases(view: self.viewType, slide: self.slideType) {[weak self](releaseData) in
            self?.releaseData = releaseData
        }
        if let results = self.releaseData?.results {
            self.releases = results
        }
        self.isLoading = false

        switch (self.viewType, self.slideType) {
        case (0, 0):
            self.viewName = "All Unlistened"
        case (0, 1):
            self.viewName = "All Released"
        case (0, 2):
            self.viewName = "All Upcoming"
        case (0, 3):
            self.viewName = "Error"
        case (1, 0):
            self.viewName = "Your Unlistened"
        case (1, 1):
            self.viewName = "Your Released"
        case (1, 2):
            self.viewName = "Your Upcoming"
        case (1, 3):
            self.viewName = "Your Fresh"
        default:
            self.viewName = "Error"
        }

        Answers.logCustomEvent(withName: self.viewName, customAttributes: nil)
    }

    func loadMoreReleases() {
        self.isLoading = true
        let currentPage = Int(self.releaseData.currentPage)!
        let nextPage = currentPage+1
        let offset = releases.count
        let limit = 50

        JSONClient.sharedClient.getReleases(view: self.viewType, slide: self.slideType, page: nextPage, limit: limit, offset: offset) {[weak self](releaseData) in
            self?.releaseData = releaseData
        }
        self.releases = self.releases + (self.releaseData?.results)!
        self.isLoading = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if defaults.username == nil {
            defaults.logged = false
        }


        if self.tabBarController?.selectedIndex == 0 {
            viewType = 0
            self.title = "All Releases"
        } else {
            viewType = 1
            self.title = "Your Releases"
            // Add fourth segmented control ...
            self.releasesSegmentedControl.insertSegment(withTitle: "Fresh", at: 3, animated: false)
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(actOnLoggedInNotification),
                                               name: .LoggedIn,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(actOnLoggedOutNotification),
                                               name: .LoggedOut,
                                               object: nil)

        self.refreshControl?.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)

        // Load initial batch of releases...
        self.tableView.tableFooterView = self.footerView
        DispatchQueue.global(qos: .background).async(execute: {
            self.loadFirstReleases()
            DispatchQueue.main.async(execute: {
                self.tableView.reloadData()
                self.tableView.tableFooterView = UIView()
            })
        })


        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.releases.count
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> ReleaseTableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "releaseInfoCell", for: indexPath) as! ReleaseTableViewCell

        // Configure the cell...

        let releaseInfo = releases[indexPath.row]
        cell.configure(releaseInfo: releaseInfo)

        //cell.selectionStyle = .none

        // Image loading.
        cell.artIndicator.startAnimating()
        cell.thumbUrl = releaseInfo.thumbUrl // For recycled cells' late image loads.


        if let image = releaseInfo.thumbUrl.cachedImage {
            // Cached: set immediately.
            cell.artImageView.image = image
            cell.artImageView.alpha = 1
        } else {
            // Not cached, so load then fade it in.
            cell.artImageView.alpha = 0
            releaseInfo.thumbUrl.fetchImage { image in
                // Check the cell hasn't recycled while loading.
                if cell.thumbUrl == releaseInfo.thumbUrl {
                    cell.artImageView.image = image
                    UIView.animate(withDuration: 0.3) {
                        cell.artImageView.alpha = 1
                    }
                }
            }
        }

        let rowsToLoadFromBottom = 20

        if !self.isLoading && indexPath.row >= (releases.count - rowsToLoadFromBottom) {
            let currentPage = Int(releaseData.currentPage)!
            let totalPages = Int(releaseData.totalPages)!
            if currentPage < totalPages {
                //print("load more")
                self.tableView.tableFooterView = self.footerView
                DispatchQueue.global(qos: .background).async(execute: {
                    self.loadMoreReleases()
                    DispatchQueue.main.async(execute: {
                        self.tableView.reloadData()
                        self.tableView.tableFooterView = UIView()
                    })
                })
            }
        }

        return cell
    }

    @objc func handleRefresh(refreshControl: UIRefreshControl) {
        releases.removeAll()
        tableView.reloadData()
        DispatchQueue.global(qos: .background).async(execute: {
            self.loadFirstReleases()
            DispatchQueue.main.async(execute: {
                self.tableView.reloadData()
                refreshControl.endRefreshing()
            })
        })
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {

        let releaseInfo = self.releases[indexPath.row]


        let listened = UITableViewRowAction(style: .normal, title: "Listened") { action, index in
            if !defaults.logged {
                if UIDevice().screenType == .iPhone4 {
                    let loginViewController = self.storyboard?.instantiateViewController(withIdentifier: "LogRegPromptSmall") as! UINavigationController
                    DispatchQueue.main.async {
                        self.present(loginViewController, animated: true, completion: nil)
                    }
                } else {
                    let loginViewController = self.storyboard?.instantiateViewController(withIdentifier: "LogRegPrompt") as! UINavigationController
                    DispatchQueue.main.async {
                        self.present(loginViewController, animated: true, completion: nil)
                    }
                }
            } else {
                DispatchQueue.global(qos: .background).async(execute: {
                    let success = releaseInfo.toggleListenStatus()
                    DispatchQueue.main.async(execute: {
                        if success == "1" {
                            // remove or add unread marker back in
                            let cell = self.tableView.cellForRow(at: indexPath) as! ReleaseTableViewCell
                            if self.releases[indexPath.row].listenStatus == "0" {
                                self.releases[indexPath.row].listenStatus = "1"
                                cell.listenedIndicatorView.isHidden = true
                                Answers.logCustomEvent(withName: "Listened", customAttributes: ["Release ID":releaseInfo.releaseId])
                            } else {
                                self.releases[indexPath.row].listenStatus = "0"
                                cell.listenedIndicatorView.isHidden = false
                                 Answers.logCustomEvent(withName: "Unlistened", customAttributes: ["Release ID":releaseInfo.releaseId])
                            }

                            tableView.setEditing(false, animated: true)
                        }
                    })
                })
            }
        }

        if releaseInfo.listenStatus == "1" {
            listened.title = "Didn't Listen"
        }
        listened.backgroundColor = .bg

        return [listened]

    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let previousIndexPath = selectedIndexPath
        if indexPath == selectedIndexPath {
            selectedIndexPath = nil
        } else {
            selectedIndexPath = indexPath
        }

        var indexPaths : Array<IndexPath> = []
        if let previous = previousIndexPath {
            indexPaths += [previous]
        }
        if let current = selectedIndexPath {
            indexPaths += [current]
        }
        if indexPaths.count > 0 {
            tableView.beginUpdates()
            //tableView.reloadRows(at: indexPaths, with: UITableViewRowAnimation.automatic)
            tableView.endUpdates()
        }
    }
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as! ReleaseTableViewCell).watchFrameChanges()
    }

    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as! ReleaseTableViewCell).ignoreFrameChanges()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        for cell in tableView.visibleCells as! [ReleaseTableViewCell] {
            cell.ignoreFrameChanges()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        for cell in tableView.visibleCells as! [ReleaseTableViewCell] {
            cell.watchFrameChanges()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !defaults.logged && self.tabBarController?.selectedIndex == 1 {
            let controller = UIDevice().screenType == .iPhone4 ? "LogRegPromptSmall" : "LogRegPrompt"
            let loginViewController = storyboard?.instantiateViewController(withIdentifier: controller) as! UINavigationController
            DispatchQueue.main.async {
                self.present(loginViewController, animated: true, completion: nil)
            }
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath == selectedIndexPath {
            return ReleaseTableViewCell.expandedHeight
        } else {
            return ReleaseTableViewCell.defaultHeight
        }
    }


    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */


    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

        if segue.identifier == "showArtistReleases",
            let destination = segue.destination as? ArtistReleasesTableViewController,
            let releaseIndex = tableView.indexPathForSelectedRow?.row {
            let artistId = releases[releaseIndex].artistId
            let artistName = releases[releaseIndex].artistName
            self.lastSelectedArtistId = artistId
            self.lastSelectedArtistName = artistName
            destination.artistId = artistId
            destination.artistName = artistName
        } else if segue.identifier == "showArtistReleases",
            let destination = segue.destination as? ArtistReleasesTableViewController {
            destination.artistId = self.lastSelectedArtistId
            destination.artistName = self.lastSelectedArtistName
        }
    }

    @objc func actOnLoggedInNotification() {
        //print("Logged in")
        releases.removeAll()
        tableView.reloadData()
        self.tableView.tableFooterView = self.footerView
        DispatchQueue.global(qos: .background).async(execute: {
            self.loadFirstReleases()
            DispatchQueue.main.async(execute: {
                self.tableView.reloadData()
                self.tableView.tableFooterView = UIView()
            })
        })
    }

    @objc func actOnLoggedOutNotification() {
        //print("Logged out")
        releases.removeAll()
        tableView.reloadData()
        DispatchQueue.global(qos: .background).async(execute: {
            self.loadFirstReleases()
            DispatchQueue.main.async(execute: {
                self.tableView.reloadData()
            })
        })
    }
}
