//
//  T2GViewController.swift
//  Table2GridConcept
//
//  Created by Michal Švácha on 25/03/15.
//  Copyright (c) 2015 Michal Švácha. All rights reserved.
//

import UIKit

protocol T2GViewControllerDelegate {
    /// Datasource methods
    
    func cellForIndexPath(indexPath: NSIndexPath, frame: CGRect) -> T2GCell
    func numberOfSectionsInT2GView() -> Int
    func numberOfCellsInSection(section: Int) -> Int
    func titleForHeaderInSection(section: Int) -> String?
    func updateCellForIndexPath(cell: T2GCell, indexPath: NSIndexPath)
    
    /// View methods
    
    func cellPadding(mode: T2GLayoutMode) -> CGFloat
    func dimensionsForCell(mode: T2GLayoutMode) -> CGSize
    func willSelectCellAtIndexPath(indexPath: NSIndexPath) -> NSIndexPath?
    func didSelectCellAtIndexPath(indexPath: NSIndexPath)
    func willDeselectCellAtIndexPath(indexPath: NSIndexPath) -> NSIndexPath?
    func didDeselectCellAtIndexPath(indexPath: NSIndexPath)
    func didSelectDrawerButtonAtIndex(indexPath: NSIndexPath, buttonIndex: Int)
    func willRemoveCellAtIndexPath(indexPath: NSIndexPath)
}

protocol T2GDropDelegate {
    func didDropCell(cell: T2GCell, onCell: T2GCell, completion: () -> Void, failure: () -> Void)
}

enum T2GLayoutMode {
    case Table
    case Collection
    
    init(){
        self = .Table
    }
}

private enum T2GScrollingSpeed {
    case Slow
    case Normal
    case Fast
}

enum T2GViewTags: Int {
    case cellConstant = 333
    case editingModeToolbar = 777777
    case checkboxButton = 666666
    case cellDrawerButtonConstant = 555555
}

class T2GViewController: T2GScrollController, T2GCellDelegate, T2GCellDragAndDropDelegate {
    var scrollView: UIScrollView!
    var layoutMode: T2GLayoutMode = T2GLayoutMode()
    var openCellTag: Int = -1
    
    var refreshControl: UIControl?
    
    var lastSpeedOffset: CGPoint = CGPointMake(0, 0)
    var lastSpeedOffsetCaptureTime: NSTimeInterval = 0
    
    var isEditingModeActive: Bool = false {
        didSet {
            if !self.isEditingModeActive {
                self.editingModeSelection = [Int : Bool]()
            }
        }
    }
    var editingModeSelection = [Int : Bool]()
    
    //TODO: Calculate the number based on the screen size
    private var visibleCellCount: Int {
        get {
            if self.layoutMode == .Table {
                return 10
            } else {
                return 20
            }
        }
    }
    
    var delegate: T2GViewControllerDelegate! {
        didSet {
            for index in 0..<self.visibleCellCount {
                self.insertRowWithTag(index + T2GViewTags.cellConstant.rawValue)
            }
            self.scrollView.contentSize = self.contentSizeForMode(self.layoutMode)
        }
    }
    
    var dropDelegate: T2GDropDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let navigationCtr = self.navigationController {
            self.statusBarBackgroundView = UIView(frame: CGRectMake(0, 0, self.view.frame.size.width, 20))
            self.statusBarBackgroundView!.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.07)
            navigationCtr.view.addSubview(self.statusBarBackgroundView!)
            
            navigationCtr.navigationBar.barTintColor = self.statusBarBackgroundViewColor
            navigationCtr.navigationBar.tintColor = .whiteColor()
        }
        
        self.scrollView = UIScrollView()
        self.scrollView.backgroundColor = UIColor(red: 238.0/255.0, green: 233.0/255.0, blue: 233/255.0, alpha: 1.0)
        self.view.addSubview(scrollView)
        
        // View must be added to hierarchy before setting constraints.
        self.scrollView.setTranslatesAutoresizingMaskIntoConstraints(false)
        let views = ["view": self.view, "scroll_view": scrollView]
        
        var constH = NSLayoutConstraint.constraintsWithVisualFormat("H:|[scroll_view]|", options: .AlignAllCenterY, metrics: nil, views: views)
        view.addConstraints(constH)
        
        var constW = NSLayoutConstraint.constraintsWithVisualFormat("V:|[scroll_view]|", options: .AlignAllCenterX, metrics: nil, views: views)
        view.addConstraints(constW)
    }
    
    override func viewDidAppear(animated: Bool) {
        self.scrollView.delegate = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //MARK: - Editing mode
    
    func toggleEdit() {
        if self.openCellTag != -1 {
            if let view = self.scrollView!.viewWithTag(self.openCellTag) as? T2GCell {
                view.closeCell()
            }
        }
        
        self.toggleEditingMode(!self.isEditingModeActive)
        self.toggleToolbar()
    }
    
    //TODO: Move multiple items
    func moveBarButtonPressed() {
        println("Not implemented yet.")
    }
    
    func deleteBarButtonPressed() {
        for key in self.editingModeSelection.keys {
            if self.editingModeSelection[key] == true {
                self.removeRowAtIndexPath(NSIndexPath(forRow: key, inSection: 0), notifyDelegate: true)
            }
        }
        
        self.editingModeSelection = [Int : Bool]()
    }
    
    func toggleToolbar() {
        if let bar = self.view.viewWithTag(T2GViewTags.editingModeToolbar.rawValue) {
            bar.removeFromSuperview()
            self.scrollView.contentSize = self.contentSizeForMode(self.layoutMode)
        } else {
            let bar = UIToolbar(frame: CGRectMake(0, self.view.frame.size.height - 44, self.view.frame.size.width, 44))
            bar.tag = T2GViewTags.editingModeToolbar.rawValue
            bar.translucent = false
            
            let leftItem = UIBarButtonItem(title: "Move", style: UIBarButtonItemStyle.Plain, target: self, action: "moveBarButtonPressed")
            let rightItem = UIBarButtonItem(title: "Delete", style: UIBarButtonItemStyle.Plain, target: self, action: "deleteBarButtonPressed")
            let space = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FlexibleSpace, target: nil, action: nil)
            bar.items = [leftItem, space, rightItem]
            
            self.scrollView.contentSize = CGSizeMake(self.scrollView.contentSize.width, self.scrollView.contentSize.height + 44.0)
            bar.alpha = 0.0
            self.view.addSubview(bar)
            
            UIView.animateWithDuration(0.3, animations: { () -> Void in
                bar.alpha = 1.0
            })
        }
    }
    
    func toggleEditingMode(flag: Bool) {
        self.isEditingModeActive = flag
        
        for view in self.scrollView.subviews {
            if let cell = view as? T2GCell {
                let isSelected = self.editingModeSelection[cell.tag - T2GViewTags.cellConstant.rawValue] ?? false
                cell.toggleMultipleChoice(flag, mode: self.layoutMode, selected: isSelected, animated: true)
            }
        }
    }
    
    //MARK: - CRUD methods
    
    func insertRowAtIndexPath(indexPath: NSIndexPath) {
        UIView.animateWithDuration(0.3, animations: { () -> Void in
            for cell in self.scrollView.subviews {
                if cell.tag >= (indexPath.row + T2GViewTags.cellConstant.rawValue) {
                    if let c = cell as? T2GCell {
                        let newFrame = self.frameForCell(self.layoutMode, index: c.tag - T2GViewTags.cellConstant.rawValue + 1)
                        c.frame = newFrame
                        c.tag = c.tag + 1
                        self.delegate.updateCellForIndexPath(c, indexPath: NSIndexPath(forRow: c.tag - T2GViewTags.cellConstant.rawValue, inSection: 0))
                    }
                }
            }
        }, completion: { (_) -> Void in
            UIView.animateWithDuration(0.3, animations: { () -> Void in
                self.scrollView.contentSize = self.contentSizeForMode(self.layoutMode)
            }, completion: { (_) -> Void in
                self.insertRowWithTag(indexPath.row + T2GViewTags.cellConstant.rawValue, animated: true)
                return
            })
        })
    }
    
    private func insertRowWithTag(tag: Int, animated: Bool = false) -> Int {
        if let cell = self.scrollView.viewWithTag(tag) {
            return cell.tag
        } else {
            let indexPath = NSIndexPath(forRow: tag - T2GViewTags.cellConstant.rawValue, inSection: 0)
            let frame = self.frameForCell(self.layoutMode, index: indexPath.row)
            let cellView = self.delegate.cellForIndexPath(indexPath, frame: frame)
            cellView.tag = tag
            
            if self.isEditingModeActive {
                let isSelected = self.editingModeSelection[cellView.tag - T2GViewTags.cellConstant.rawValue] ?? false
                cellView.toggleMultipleChoice(true, mode: self.layoutMode, selected: isSelected, animated: false)
            }
            
            let isDragged = self.view.viewWithTag(tag) != nil
            
            cellView.delegate = self
            cellView.alpha = (animated || isDragged) ? 0 : 1
            self.scrollView.addSubview(cellView)
            
            if animated && !isDragged {
                UIView.animateWithDuration(0.3, animations: { () -> Void in
                    cellView.alpha = 1.0
                })
            }
            
            return cellView.tag
        }
    }
    
    func removeRowAtIndexPath(indexPath: NSIndexPath, notifyDelegate: Bool = false) {
        if let view = self.scrollView!.viewWithTag(indexPath.row + T2GViewTags.cellConstant.rawValue) as? T2GCell {
            if notifyDelegate {
                self.delegate.willRemoveCellAtIndexPath(indexPath)
            }
            
            if self.openCellTag == view.tag {
                view.closeCell()
            }
            
            UIView.animateWithDuration(0.6, animations: { () -> Void in
                view.frame = CGRectMake(view.frame.origin.x - 40, view.frame.origin.y, view.frame.size.width, view.frame.size.height)
            }, completion: { (_) -> Void in
                UIView.animateWithDuration(0.2, animations: { () -> Void in
                    view.frame = CGRectMake(self.scrollView.bounds.width + 40, view.frame.origin.y, view.frame.size.width, view.frame.size.height)
                }, completion: { (_) -> Void in
                    view.removeFromSuperview()
                        
                    UIView.animateWithDuration(0.3, animations: { () -> Void in
                        for cell in self.scrollView.subviews {
                            if cell.tag > view.tag {
                                if let c = cell as? T2GCell {
                                    let newFrame = self.frameForCell(self.layoutMode, index: c.tag - T2GViewTags.cellConstant.rawValue - 1)
                                    c.frame = newFrame
                                    c.tag = c.tag - 1
                                    self.delegate.updateCellForIndexPath(c, indexPath: NSIndexPath(forRow: c.tag - T2GViewTags.cellConstant.rawValue, inSection: 0))
                                }
                            }
                        }
                    }, completion: { (_) -> Void in
                        UIView.animateWithDuration(0.3, animations: { () -> Void in
                            self.scrollView.contentSize = self.contentSizeForMode(self.layoutMode)
                        }, completion: { (_) -> Void in
                            self.displayMissingCells(self.layoutMode)
                        })
                    })
                })
            })
        }
    }
    
    //MARK: - Helper methods
    
    func contentSizeForMode(mode: T2GLayoutMode) -> CGSize {
        let dimensions = self.delegate.dimensionsForCell(mode)
        let viewX = mode == .Collection ? self.delegate.cellPadding(mode) : (self.view.frame.size.width - dimensions.width) / 2
        let divisor = mode == .Collection ? 3 : 1
        let lineCount = Int(ceil(Double((self.delegate.numberOfCellsInSection(0) - 1) / divisor)))
        let ypsilon = viewX + (CGFloat(lineCount) * (dimensions.height + self.delegate.cellPadding(mode)))
        let height = ypsilon + dimensions.height + self.delegate.cellPadding(mode)
        
        return CGSize(width: self.view.frame.size.width, height: height)
    }
    
    func frameForCell(mode: T2GLayoutMode, index: Int = 0) -> CGRect {
        let superviewFrame = self.view.frame
        let dimensions = self.delegate.dimensionsForCell(mode)
        
        if mode == .Collection {
            /// Assuming that the collection is square of course
            let middle = (superviewFrame.size.width - dimensions.width) / 2
            let left = (middle - dimensions.width) / 2
            let right = middle + dimensions.width + left
            var xCoords = [left, middle, right]
            let yCoord = self.delegate.cellPadding(mode) + (CGFloat(index / xCoords.count) * (dimensions.height + self.delegate.cellPadding(mode)))
            let frame = CGRectMake(CGFloat(xCoords[index % xCoords.count]), yCoord, dimensions.width, dimensions.height)
            
            return frame
            
        } else {
            let viewX = (superviewFrame.size.width - dimensions.width) / 2
            let ypsilon = viewX + (CGFloat(index) * (dimensions.height + self.delegate.cellPadding(mode)))
            return CGRectMake(viewX, ypsilon, dimensions.width, dimensions.height)
        }
    }
    
    private func indicesForVisibleCells(mode: T2GLayoutMode) -> [Int] {
        let frame = self.scrollView.bounds
        var res = [Int]()
        let dimensions = self.delegate.dimensionsForCell(mode)
        
        if mode == .Collection {
            var firstIndex = Int(floor((frame.origin.y - dimensions.height) / (dimensions.height + self.delegate.cellPadding(mode)))) * 3
            if firstIndex < 0 {
                firstIndex = 0
            }
            
            var lastIndex = firstIndex + 2 * self.visibleCellCount
            if self.delegate.numberOfCellsInSection(0) - 1 < lastIndex {
                lastIndex = self.delegate.numberOfCellsInSection(0) - 1
            }
            
            for index in firstIndex...lastIndex {
                res.append(index)
            }
        } else {
            var firstIndex = Int(floor((frame.origin.y - dimensions.height) / (dimensions.height + self.delegate.cellPadding(mode))))
            if firstIndex < 0 {
                firstIndex = 0
            }
            
            var lastIndex = firstIndex + self.visibleCellCount
            if self.delegate.numberOfCellsInSection(0) - 1 < lastIndex {
                lastIndex = self.delegate.numberOfCellsInSection(0) - 1
            }
            
            for index in firstIndex...lastIndex {
                res.append(index)
            }
        }
        
        return res
    }
    
    //MARK: - View transformation (Table <-> Collection)
    
    func transformView() {
        self.transformViewWithCompletion() {()->Void in}
    }
    
    //TODO: Rearranging items when deep in view
    private func transformViewWithCompletion(completionClosure:() -> Void) {
        let collectionClosure = {() -> T2GLayoutMode in
            let indicesExtremes = self.firstAndLastTags(self.scrollView.subviews)
            var from = (indicesExtremes.highest) + 1
            if from > self.delegate.numberOfCellsInSection(0) {
                from = self.delegate.numberOfCellsInSection(0) - 1 + T2GViewTags.cellConstant.rawValue
            }
            
            var to = (indicesExtremes.highest) + 10
            if to > self.delegate.numberOfCellsInSection(0) {
                to = self.delegate.numberOfCellsInSection(0) - 1 + T2GViewTags.cellConstant.rawValue
            }
            
            
            for index in from...to {
                self.insertRowWithTag(index)
            }
            
            return .Collection
        }
        
        let mode = self.layoutMode == .Collection ? T2GLayoutMode.Table : collectionClosure()
        self.scrollView.contentSize = self.contentSizeForMode(mode)
        self.displayMissingCells(self.layoutMode)
        self.displayMissingCells(mode)
        
        UIView.animateWithDuration(0.8, animations: { () -> Void in
            
            for view in self.scrollView.subviews {
                if let cell = view as? T2GCell {
                    let frame = self.frameForCell(mode, index: cell.tag - T2GViewTags.cellConstant.rawValue)
                    
                    /*
                    * Not really working - TBD
                    *
                    if !didAdjustScrollview {
                    self.scrollView.scrollRectToVisible(CGRectMake(0, frame.origin.y - 12 - 64, self.scrollView.bounds.size.width, self.scrollView.bounds.size.height), animated: false)
                    didAdjustScrollview = true
                    }
                    */
                    
                    cell.changeFrameParadigm(mode, frame: frame)
                }
            }
            
            }) { (Bool) -> Void in
                //self.scrollView.contentSize = self.contentSizeForCurrentMode()
                self.performSubviewCleanup()
                completionClosure()
        }
        
        self.layoutMode = mode
    }
    
    //MARK: - Rotation handler
    
    override func willAnimateRotationToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
        super.willAnimateRotationToInterfaceOrientation(toInterfaceOrientation, duration: duration)
        
        let indicesExtremes = self.firstAndLastTags(self.scrollView.subviews)
        let from = (indicesExtremes.highest) + 1
        var to = (indicesExtremes.highest) + 10
        if (to - T2GViewTags.cellConstant.rawValue) < self.delegate.numberOfCellsInSection(0) {
            for index in from...to {
                self.insertRowWithTag(index)
            }
        }
        
        UIView.animateWithDuration(0.8, animations: { () -> Void in
            if let bar = self.view.viewWithTag(T2GViewTags.editingModeToolbar.rawValue) as? UIToolbar {
                let height: CGFloat = UIInterfaceOrientationIsLandscape(toInterfaceOrientation) ? 35.0 : 44.0
                bar.frame = CGRectMake(0, self.view.frame.size.height - height, self.view.frame.size.width, height)
            }
            
            for view in self.scrollView.subviews {
                if let cell = view as? T2GCell {
                    let frame = self.frameForCell(self.layoutMode, index: cell.tag - T2GViewTags.cellConstant.rawValue)
                    cell.changeFrameParadigm(self.layoutMode, frame: frame)
                }
            }
            
            }) { (Bool) -> Void in
                self.scrollView.contentSize = self.contentSizeForMode(self.layoutMode)
                self.performSubviewCleanup()
        }
    }
    
    //MARK: - ScrollView delegate
    
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        self.performSubviewCleanup()
    }
    
    override func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        super.scrollViewDidEndDragging(scrollView, willDecelerate: decelerate)
        
        if !decelerate {
            self.performSubviewCleanup()
        }
    }
    
    private func performSubviewCleanup() {
        for view in self.scrollView.subviews {
            if let cell = view as? T2GCell {
                if !CGRectIntersectsRect(scrollView.bounds, cell.frame) {
                    cell.removeFromSuperview()
                }
            }
        }
    }
    
    override func scrollViewDidScroll(scrollView: UIScrollView) {
        super.scrollViewDidScroll(scrollView)
        
        var currentOffset = scrollView.contentOffset;
        var currentTime = NSDate.timeIntervalSinceReferenceDate()
        var currentSpeed = T2GScrollingSpeed.Slow
        
        if(currentTime - self.lastSpeedOffsetCaptureTime > 0.1) {
            var distance = currentOffset.y - self.lastSpeedOffset.y
            var scrollSpeed = fabsf(Float((distance * 10) / 1000))
            
            if (scrollSpeed > 6) {
                currentSpeed = .Fast
            } else if scrollSpeed > 0.5 {
                currentSpeed = .Normal
            }
            
            self.lastSpeedOffset = currentOffset
            self.lastSpeedOffsetCaptureTime = currentTime
        }
        
        let extremes = self.firstAndLastTags(scrollView.subviews)
        let startingPoint = self.scrollDirection == .Up ? extremes.lowest : extremes.highest
        let endingPoint = self.scrollDirection == .Up ? extremes.highest : extremes.lowest
        let edgeCondition = self.scrollDirection == .Up ? T2GViewTags.cellConstant.rawValue : self.delegate.numberOfCellsInSection(0) + T2GViewTags.cellConstant.rawValue - 1
        
        if let cell = scrollView.viewWithTag(endingPoint) as? T2GCell {
            if !CGRectIntersectsRect(scrollView.bounds, cell.frame) {
                cell.removeFromSuperview()
            }
        }
        
        if let edgeCell = scrollView.viewWithTag(startingPoint) as? T2GCell {
            if CGRectIntersectsRect(scrollView.bounds, edgeCell.frame) && startingPoint != edgeCondition {
                let firstAddedTag = self.addRowsWhileScrolling(self.scrollDirection, startTag: startingPoint)
                if (currentSpeed == .Fast || currentSpeed == .Normal) && firstAddedTag != edgeCondition {
                    let secondAddedTag = self.addRowsWhileScrolling(self.scrollDirection, startTag: firstAddedTag)
                    if (currentSpeed == .Fast) && secondAddedTag != edgeCondition {
                        let thirdAddedTag = self.addRowsWhileScrolling(self.scrollDirection, startTag: secondAddedTag)
                        if (currentSpeed == .Fast || self.layoutMode == .Collection) && thirdAddedTag != edgeCondition {
                            let fourthAddedTag = self.addRowsWhileScrolling(self.scrollDirection, startTag: secondAddedTag)
                        }
                    }
                }
            }
        } else {
            self.displayMissingCells(self.layoutMode)
        }
    }
    
    func displayMissingCells(mode: T2GLayoutMode) {
        let indices = self.indicesForVisibleCells(mode)
        for index in indices[0]...indices[indices.count - 1] {
            self.insertRowWithTag(index + T2GViewTags.cellConstant.rawValue, animated: true)
        }
    }
    
    func addRowsWhileScrolling(direction: T2GScrollDirection, startTag: Int) -> Int {
        var multiplier = direction == .Up ? -1 : 1
        var firstTag = startTag + (1 * multiplier)
        var secondTag = startTag + (2 * multiplier)
        var thirdTag = startTag + (3 * multiplier)
        
        let firstAdditionalCondition = direction == .Up ? secondTag - T2GViewTags.cellConstant.rawValue > 0 : secondTag - T2GViewTags.cellConstant.rawValue < (self.delegate.numberOfCellsInSection(0) - 1)
        let secondAdditionalCondition = direction == .Up ? thirdTag - T2GViewTags.cellConstant.rawValue > 0 : thirdTag - T2GViewTags.cellConstant.rawValue < (self.delegate.numberOfCellsInSection(0) - 1)
        
        var lastTag = self.insertRowWithTag(firstTag)
        
        if self.layoutMode == .Collection {
            if firstAdditionalCondition {
                lastTag = self.insertRowWithTag(secondTag)
                
                if secondAdditionalCondition {
                    lastTag = self.insertRowWithTag(thirdTag)
                }
            }
        }
        
        return lastTag
    }
    
    //TODO: Functional approach or for cycle?
    func firstAndLastTags(subviews: [AnyObject]) -> (lowest: Int, highest: Int) {
        /*
        let startValues = (lowest: Int.max, highest: Int.min)
        var minMax:(lowest: Int, highest: Int) = subviews.reduce(startValues) { prev, next in
            (next as? T2GCell).map {
                (min(prev.lowest, $0.tag), max(prev.highest, $0.tag))
            } ?? prev
        }
        */
        
        var lowest = Int.max
        var highest = Int.min
        
        for view in subviews {
            if let cell = view as? T2GCell {
                lowest = lowest > cell.tag ? cell.tag : lowest
                highest = highest < cell.tag ? cell.tag : highest
            }
        }
        
        return (lowest, highest)
    }
    
    //MARK: - T2GCell delegate
    
    func cellStartedSwiping(tag: Int) {
        if self.openCellTag != -1 && self.openCellTag != tag {
            let cell = self.view.viewWithTag(self.openCellTag) as? T2GCell
            cell?.closeCell()
        }
    }
    
    func didCellOpen(tag: Int) {
        self.openCellTag = tag
    }
    
    func didCellClose(tag: Int) {
        self.openCellTag = -1
    }
    
    func didSelectButton(tag: Int, index: Int) {
        self.delegate.didSelectDrawerButtonAtIndex(NSIndexPath(forRow: tag, inSection: 0), buttonIndex: index)
    }
    
    func didSelectMultipleChoiceButton(tag: Int, selected: Bool) {
        self.editingModeSelection[tag - T2GViewTags.cellConstant.rawValue] = selected
    }
    
    //MARK: - T2GCellDragAndDrop delegate
    
    func findBiggestOverlappingView(excludedTag: Int, frame: CGRect) -> UIView? {
        var winningView:UIView?
        
        var winningRect:CGRect = CGRectMake(0, 0, 0, 0)
        
        for view in self.scrollView.subviews {
            if let c = view as? T2GCell {
                if c.tag != excludedTag {
                    if CGRectIntersectsRect(frame, c.frame) {
                        if winningView == nil {
                            winningView = c
                            winningRect = winningView!.frame
                        } else {
                            if (c.frame.size.height * c.frame.size.width) > (winningRect.size.height * winningRect.size.width) {
                                winningView!.alpha = 1.0
                                winningView = c
                                winningRect = winningView!.frame
                            } else {
                                c.alpha = 1.0
                            }
                        }
                    } else {
                        c.alpha = 1.0
                    }
                }
            }
        }
        
        return winningView
    }
    
    func didCellMove(tag: Int, frame: CGRect) {
        let height: CGFloat = 30.0
        
        var frameInView = self.scrollView.convertRect(frame, toView: self.view)
        
        var topOrigin = self.scrollView.convertPoint(CGPointMake(self.scrollView.contentOffset.x, self.scrollView.contentOffset.y), toView: self.view)
        if let navigationBar = self.navigationController {
            topOrigin.y += navigationBar.navigationBar.frame.origin.y + navigationBar.navigationBar.frame.size.height
        }
        let topStrip = CGRectMake(0, topOrigin.y, self.scrollView.frame.size.width, height)
        
        if CGRectIntersectsRect(topStrip, frameInView) {
            let subview = self.view.viewWithTag(tag)
            let isFirstEncounter = subview?.superview is UIScrollView
            self.view.addSubview(subview!)
            
            if isFirstEncounter {
                let speedCoefficient = self.coefficientForOverlappingFrames(topStrip, overlapping: frameInView) * -1
                self.scrollContinously(speedCoefficient, stationaryFrame: topStrip, overlappingView: subview)
            }
        }
        
        let bottomOrigin = self.scrollView.convertPoint(CGPointMake(0, self.scrollView.contentOffset.y + self.scrollView.frame.size.height - height), toView: self.view)
        let bottomStrip = CGRectMake(0, bottomOrigin.y, self.scrollView.frame.size.width, height)
        
        if CGRectIntersectsRect(bottomStrip, frameInView) {
            let subview = self.view.viewWithTag(tag)
            let isFirstEncounter = subview?.superview is UIScrollView
            self.view.addSubview(subview!)
            
            if isFirstEncounter {
                let speedCoefficient = self.coefficientForOverlappingFrames(bottomStrip, overlapping: frameInView)
                self.scrollContinously(speedCoefficient, stationaryFrame: bottomStrip, overlappingView: subview)
            }
        }
        
        let winningView = self.findBiggestOverlappingView(tag, frame: frame)
        winningView?.alpha = 0.3
    }
    
    func scrollContinously(speedCoefficient: CGFloat, stationaryFrame: CGRect, overlappingView: UIView?) {
        UIView.animateWithDuration(0.1, animations: { () -> Void in
            var toMove = self.scrollView.contentOffset.y + (32.0 * speedCoefficient)
            
            if speedCoefficient < 0 {
                var minContentOffset: CGFloat = 0.0
                if let navigationBar = self.navigationController?.navigationBar {
                    minContentOffset -= (navigationBar.frame.origin.y + navigationBar.frame.size.height)
                }
                
                if toMove < minContentOffset {
                    toMove = minContentOffset
                }
            } else {
                let maxContentOffset = self.scrollView.contentSize.height - self.scrollView.frame.size.height
                if toMove > maxContentOffset {
                    toMove = maxContentOffset
                }
            }
            
            self.scrollView.contentOffset = CGPointMake(self.scrollView.contentOffset.x, toMove)
        }, completion: { (_) -> Void in
            if let overlappingCellView = overlappingView {
                
                var shouldContinueScrolling = true
                if speedCoefficient < 0 {
                    var minContentOffset: CGFloat = 0.0
                    if let navigationBar = self.navigationController?.navigationBar {
                        minContentOffset -= (navigationBar.frame.origin.y + navigationBar.frame.size.height)
                    }
                    
                    if self.scrollView.contentOffset.y == minContentOffset {
                        shouldContinueScrolling = false
                    }
                } else {
                    let maxContentOffset = self.scrollView.contentSize.height - self.scrollView.frame.size.height
                    if self.scrollView.contentOffset.y == self.scrollView.contentSize.height - self.scrollView.frame.size.height {
                        shouldContinueScrolling = false
                    }
                }
                
                let newOverlappingViewFrame = overlappingCellView.frame
                    
                if shouldContinueScrolling && CGRectIntersectsRect(stationaryFrame, newOverlappingViewFrame) {
                    let speedCoefficient2 = self.coefficientForOverlappingFrames(stationaryFrame, overlapping: newOverlappingViewFrame) * (speedCoefficient < 0 ? -1 : 1)
                    self.scrollContinously(speedCoefficient2, stationaryFrame: stationaryFrame, overlappingView: overlappingView)
                } else {
                    self.scrollView.addSubview(overlappingCellView)
                }
            }
        })
    }
    
    func coefficientForOverlappingFrames(stationary: CGRect, overlapping: CGRect) -> CGFloat {
        let stationarySize = stationary.size.width * stationary.size.height
        let intersection = CGRectIntersection(stationary, overlapping)
        let intersectionSize = intersection.size.height * intersection.size.width
        return intersectionSize / stationarySize
    }
    
    func didDrop(cell: T2GCell) {
        if let win = self.findBiggestOverlappingView(cell.tag, frame: cell.frame) as? T2GCell {
            win.alpha = 1.0
            
            self.dropDelegate?.didDropCell(cell, onCell: win, completion: { () -> Void in
                UIView.animateWithDuration(0.1, animations: { () -> Void in
                    let transform = CGAffineTransformMakeScale(1.07, 1.07)
                    win.transform = transform
                    
                    cell.center = win.center
                    
                    let transform2 = CGAffineTransformMakeScale(0.1, 0.1)
                    cell.transform = transform2
                }, completion: { (_) -> Void in
                    cell.removeFromSuperview()
                        
                    UIView.animateWithDuration(0.15, animations: { () -> Void in
                        let transform = CGAffineTransformMakeScale(1.0, 1.0)
                        win.transform = transform
                    }, completion: { (_) -> Void in
                        UIView.animateWithDuration(0.3, animations: { () -> Void in
                            for view in self.scrollView.subviews {
                                if let c = view as? T2GCell {
                                    if c.tag > cell.tag {
                                        let newFrame = self.frameForCell(self.layoutMode, index: c.tag - T2GViewTags.cellConstant.rawValue - 1)
                                        c.frame = newFrame
                                        c.tag = c.tag - 1
                                        self.delegate.updateCellForIndexPath(c, indexPath: NSIndexPath(forRow: c.tag - T2GViewTags.cellConstant.rawValue, inSection: 0))
                                    }
                                }
                            }
                        }, completion: { (_) -> Void in
                            UIView.animateWithDuration(0.3, animations: { () -> Void in
                                self.scrollView.contentSize = self.contentSizeForMode(self.layoutMode)
                            }, completion: { (_) -> Void in
                                self.displayMissingCells(self.layoutMode)
                            })
                        })
                    })
                })
            }, failure: { () -> Void in
                UIView.animateWithDuration(0.3) {
                    cell.frame = CGRectMake(cell.origin.x, cell.origin.y, cell.frame.size.width, cell.frame.size.height)
                }
            })
            
        } else {
            UIView.animateWithDuration(0.3) {
                cell.frame = CGRectMake(cell.origin.x, cell.origin.y, cell.frame.size.width, cell.frame.size.height)
            }
        }
    }
}
