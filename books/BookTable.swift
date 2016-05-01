//
//  BookTableViewController.swift
//  books
//
//  Created by Andrew Bennet on 09/11/2015.
//  Copyright © 2015 Andrew Bennet. All rights reserved.
//

import UIKit
import DZNEmptyDataSet
import CoreData
import CoreSpotlight

class BookTable: UITableViewController {

    @IBOutlet weak var segmentControl: UISegmentedControl!
    
    var viewHasJustLoaded = true
    
    /// The controller to get the results to display in this view
    var resultsController = appDelegate.booksStore.FetchedBooksController()
    
    func segmentToReadState(segmentIndex: Int) -> BookReadState {
        switch segmentIndex {
        case 2:
            return .Finished
        case 1:
            return .ToRead
        default:
            return .Reading
        }
    }
    
    func readStateToSegment(readState: BookReadState) -> Int {
        switch readState {
        case .Reading:
            return 0;
        case .ToRead:
            return 1
        case .Finished:
            return 2
        }
    }

    /// The currently selected read state
    var readState = BookReadState.Reading
    
    /// The UISearchController to which this UITableViewController is connected.
    var searchController = UISearchController(searchResultsController: nil)
    
    var tableViewScrollPositions = [BookReadState: CGPoint]()
    
    override func viewDidLoad() {
        // Attach this controller as a delegate on for the results controller, and perform the initial fetch.
        updatePredicate([ReadStateFilter(states: [readState])])
        resultsController.delegate = self
        try! resultsController.performFetch()
        
        // Hacky way of getting some test data. This will be remove in due course.
        self.loadDefaultDataIfFirstLaunch()
        
        // Setup the search bar.
        configureSearchBar()
        
        // Set the view of the NavigationController to be white, so that glimpses
        // of dark colours are not seen through the translucent bar when segueing from this view.
        // Also, setting the table footer removes the cell separators
        self.navigationController!.view.backgroundColor = UIColor.whiteColor()
        tableView.tableFooterView = UIView()

        // Set the DZN data set source
        tableView.emptyDataSetSource = self
        
        super.viewDidLoad()
    }
    
    override func viewDidAppear(animated: Bool) {
        // Now that the view has appeared, store the current table view offset
        // as the starting scroll positions for each of the modes.
        if viewHasJustLoaded {
        let startingOffset = tableView.contentOffset
            tableViewScrollPositions[.Reading] = startingOffset
            tableViewScrollPositions[.ToRead] = startingOffset
            tableViewScrollPositions[.Finished] = startingOffset
        }
        viewHasJustLoaded = false
        
        super.viewDidAppear(animated)
    }
    
    private func updatePredicate(filters: [BookFilter]){
        resultsController.fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: filters.map{ $0.ToPredicate() })
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.resultsController.sections![section].numberOfObjects
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        // Get a spare cell, configure the cell for the specified index path and return it
        let cell = tableView.dequeueReusableCellWithIdentifier(String(BookTableViewCell), forIndexPath: indexPath) as! BookTableViewCell
        cell.configureFromBook(resultsController.objectAtIndexPath(indexPath) as? Book)
        return cell
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
    
        let delete = UITableViewRowAction(style: .Destructive, title: "Delete") {
            action, index in
        
            let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
            let deleteAction = UIAlertAction(title: "Delete", style: .Destructive){
                _ in
                self.tableView.editing = true
                let selectedBook = self.resultsController.objectAtIndexPath(index) as! Book
                appDelegate.booksStore.DeleteBookAndDeindex(selectedBook)
                self.tableView.editing = false
                tableView.deleteRowsAtIndexPaths([index], withRowAnimation: .Automatic)
            }
            optionMenu.addAction(deleteAction)
            optionMenu.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
            
            // Bring up the action sheet
            self.presentViewController(optionMenu, animated: true, completion: nil)

        }
        delete.backgroundColor = UIColor.redColor()
        
        return [delete]
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // All cells are "editable"
        return true
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        // you need to implement this method too or you can't swipe to display the actions
    }
    
    override func restoreUserActivityState(activity: NSUserActivity) {
        if let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as! String? {
            if let selectedBook = appDelegate.booksStore.GetBook(NSURL(string: identifier)!) {
                // Update the selected segment and table on display
                segmentControl.selectedSegmentIndex = readStateToSegment(selectedBook.readState)
                selectedSegmentChanged(self)
                
                // Show the book
                performSegueWithIdentifier("showDetail", sender: selectedBook)
            }
        }
    }
    
    @IBAction func selectedSegmentChanged(sender: AnyObject) {
        // Store the scroll position for the current read state
        tableViewScrollPositions[readState] = tableView.contentOffset
        
        // Update the read state to the selected read state
        readState = segmentToReadState(segmentControl.selectedSegmentIndex)
        
        // Load the previously stored scroll position
        tableView.setContentOffset(tableViewScrollPositions[readState]!, animated: false)
        
        // Load the data
        updatePredicate([ReadStateFilter(states: [readState])])
        try! resultsController.performFetch()
        tableView.reloadData()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "addBook" {
            let navigationController = segue.destinationViewController as! NavWithReadState
            navigationController.readState = readState
        }
        else if segue.identifier == "showDetail" {
            var selectedBook: Book!
            if let bookSender = sender as? Book{
                selectedBook = bookSender
            }
            else if let cellSender = sender as? UITableViewCell {
                let selectedIndex = self.tableView.indexPathForCell(cellSender)
                selectedBook = self.resultsController.objectAtIndexPath(selectedIndex!) as! Book
            }
            let destinationNavController = segue.destinationViewController as! UINavigationController
            let destinationViewController = destinationNavController.topViewController as! BookDetails
            destinationViewController.book = selectedBook
        }
    }
}


/**
 The handling of updates from the fetched results controller.
*/
extension BookTable: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        if tableView.editing {
            return
        }
        tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        if tableView.editing {
            return
        }
        try! controller.performFetch()
        tableView.reloadData()
        tableView.endUpdates()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject object: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        if tableView.editing {
            // If the user is editing stuff directly in the table, 
            // don't worry about trying to keep it up to date here too.
            return
        }
        switch type {
        case .Update:
            if let cell = tableView.cellForRowAtIndexPath(indexPath!) as? BookTableViewCell {
                cell.configureFromBook(resultsController.objectAtIndexPath(indexPath!) as? Book)
            }
        case .Insert:
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .None)
        case .Move:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .None)
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .None)
        case .Delete:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .None)
        }
    }
}

/**
 Controls for the Search capabilities of the table.
 */
extension BookTable: UISearchResultsUpdating {
    func configureSearchBar(){
        self.searchController.searchResultsUpdater = self
        self.searchController.dimsBackgroundDuringPresentation = false
        searchController.searchBar.returnKeyType = .Done
        self.tableView.tableHeaderView = searchController.searchBar
        
        // Offset by the height of the search bar, so as to hide it on load.
        // However, the contentOffset values will change before the view appears,
        // due to the adjusted scroll view inset from the navigation bar.
        self.tableView.setContentOffset(CGPointMake(0, searchController.searchBar.frame.height), animated: false)
    }
    
    func updateSearchResultsForSearchController(searchController: UISearchController) {
        updatePredicate([ReadStateFilter(states: [readState]), TitleFilter(comparison: .Contains, text: searchController.searchBar.text!)])
        try! resultsController.performFetch()
        tableView.reloadData()
    }
}


/**
 Functions controlling the DZNEmptyDataSet.
 */
extension BookTable : DZNEmptyDataSetSource {
    
    private func IsShowingSearchResults() -> Bool {
        if !searchController.active {
            // If the search controller is not active, we are definitely not searching
            return false
        }
        
        if let searchText = searchController.searchBar.text{
            // If there is some search text, we are searching if that text is not empty
            return !searchText.isEmpty
        }
        return false
    }
    
    func imageForEmptyDataSet(scrollView: UIScrollView!) -> UIImage! {
        if IsShowingSearchResults() {
            return UIImage(named: "fa-search")
        }
        return UIImage(named: "fa-book")
    }
    
    func titleForEmptyDataSet(scrollView: UIScrollView!) -> NSAttributedString! {
        let attrs = [NSFontAttributeName: UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)]
        if IsShowingSearchResults() {
            return NSAttributedString(string: "No results :(", attributes: attrs)
        }
        return NSAttributedString(string: "No books yet", attributes: attrs)
    }
    
    func descriptionForEmptyDataSet(scrollView: UIScrollView!) -> NSAttributedString! {
        let attrs = [NSFontAttributeName: UIFont.preferredFontForTextStyle(UIFontTextStyleBody)]
        if IsShowingSearchResults() {
            return NSAttributedString(string: "Try changing your search, or add a new book with the + button above.", attributes: attrs)
        }
        return NSAttributedString(string: "Add a book by clicking the + button above.", attributes: attrs)
    }
}


extension BookTable {
    func loadDefaultDataIfFirstLaunch() {
        let key = "hasLaunchedBefore"
        let launchedBefore = NSUserDefaults.standardUserDefaults().boolForKey(key)
        if launchedBefore == false {
            NSUserDefaults.standardUserDefaults().setBool(true, forKey: key)

            let booksToAdd: [(isbn: String, readState: BookReadState, titleDesc: String)] = [
                ("9780007232444", .Finished, "The Corrections"),
                ("9780099529125", .Finished, "Catch-22"),
                ("9780141187761", .Finished, "1984"),
                ("9780735611313", .Finished, "Code"),
                ("9780857282521", .ToRead, "The Entrepreneurial State"),
                ("9780330510936", .ToRead, "All the Pretty Horses"),
                ("9780006480419", .ToRead, "Neuromancer"),
                ("9780241950432", .Finished, "Catcher in the Rye"),
                ("9780099800200", .Finished, "Slaughterhouse 5"),
                ("9780006546061", .ToRead, "Farenheit 451"),
                ("9781442369054", .ToRead, "Steve Jobs"),
                ("9780007532766", .Finished, "Purity"),
                ("9780718197384", .Reading, "The Price of Inequality"),
                ("9780099889809", .Reading, "Something Happened"),
                ("9780241197790", .Finished, "The Trial"),
                ("9780340935125", .ToRead, "Indemnity Only"),
                ("9780857059994", .Finished, "The Girl in the Spider's Web"),
                ("9781846275951", .Finished, "Honourable Friends?"),
                ("9780141047973", .Finished, "23 Things They Don't Tell You About Capitalism"),
                ("9780330468466", .Finished, "The Road")
            ]
            
            for bookToAdd in booksToAdd {
                OnlineBookClient<GoogleBooksParser>.TryGetBookMetadata(GoogleBooksRequest.Search(bookToAdd.isbn).url, completionHandler: {
                    if let bookMetadata = $0 {
                        bookMetadata.isbn13 = bookToAdd.isbn
                        bookMetadata.readState = bookToAdd.readState
                        appDelegate.booksStore.CreateBook(bookMetadata)
                        self.tableView.reloadData()
                    }
                })
            }
        }
    }
}