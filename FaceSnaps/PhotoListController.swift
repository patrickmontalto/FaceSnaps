//
//  PhotoListController.swift
//  FaceSnaps
//
//  Created by Patrick Montalto on 10/1/16.
//  Copyright © 2016 Patrick Montalto. All rights reserved.
//

import UIKit
import CoreData

class PhotoListController: UIViewController {
    
    // Lazy stored property with an immediately executing closure
    // Let's us put the initialization and customization all in one place, instead of splitting it up
    // between the class body and viewDidLoad
    lazy var cameraButton: UIButton = {
        let button = UIButton(type: UIButtonType.system)
        button.setTitle("Camera", for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor(red: 254/255.0, green: 123/255.0, blue: 135/255.0, alpha: 1.0)
        
        button.addTarget(self, action: #selector(PhotoListController.presentImagePickerController), for: .touchUpInside)
        
        return button
    }()
    
    lazy var mediaPickerManager: MediaPickerManager = {
        let manager = MediaPickerManager(presentingViewController: self)
        manager.delegate = self
        return manager
    }()
    
    lazy var dataSource: PhotoDataSource = {
        return PhotoDataSource(fetchRequest: Photo.allPhotosRequest, collectionView: self.collectionView, photoDeletionDelegate: self)
    }()
    
    lazy var collectionView: UICollectionView = {
        let collectionViewLayout = UICollectionViewFlowLayout()
        
        let screenWidth = UIScreen.main.bounds.size.width
        let paddingDistance: CGFloat = 16.0
        let itemSize = (screenWidth - paddingDistance)/2.0
        
        collectionViewLayout.itemSize = CGSize(width: itemSize, height: itemSize)
        
        let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: collectionViewLayout)
        collectionView.backgroundColor = .white
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseIdentifier)
        
        collectionView.delegate = self
        
        return collectionView
    }()
    
    lazy var cancelEditingButton: UIBarButtonItem =  {
       return UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(PhotoListController.hideDeletion))
    }()
    
    var editingModeEnabled: Bool = false {
        didSet {
            if editingModeEnabled {
                cancelEditingButton.tintColor = self.view.tintColor
                cancelEditingButton.isEnabled = true
                CellAnimator.animateAllCells(inCollectionView: self.collectionView)
            } else {
                cancelEditingButton.tintColor = UIColor.clear
                cancelEditingButton.isEnabled = false
                CellAnimator.stopAnimatingAllCells(inCollectionView: self.collectionView)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        
        collectionView.dataSource = dataSource
        // Remove white space between Navbar and Collectionview
        self.automaticallyAdjustsScrollViewInsets = false
        
        self.enableLongPressDeletion()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Make sure edit mode is disabled when appearing
        editingModeEnabled = false
    }
    
    // MARK: - Layout
    
    override func viewWillLayoutSubviews() {
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(cameraButton)
        cameraButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            cameraButton.leftAnchor.constraint(equalTo: view.leftAnchor),
            cameraButton.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cameraButton.rightAnchor.constraint(equalTo: view.rightAnchor),
            cameraButton.heightAnchor.constraint(equalToConstant: 56.0),
            collectionView.leftAnchor.constraint(equalTo: view.leftAnchor),
            collectionView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
            collectionView.rightAnchor.constraint(equalTo: view.rightAnchor),
            collectionView.bottomAnchor.constraint(equalTo: cameraButton.topAnchor),
        ])
    }
    
    // MARK: - Image Picker Controller

    @objc private func presentImagePickerController() {
        mediaPickerManager.presentImagePickerController(animated: true)
    }


}

// MARK: - MediaPickerManagerDelegate
extension PhotoListController: MediaPickerManagerDelegate {
    func mediaPickerManager(manager: MediaPickerManager, didFinishPickingImage image: UIImage) {
        // We now got an image available in our PhotoListController
        
        let eaglContext = EAGLContext(api: .openGLES2)!
        let ciContext = CIContext(eaglContext: eaglContext)
        
        let photoFilterController = PhotoFilterController(image: image, context: ciContext, eaglContext: eaglContext)
        let navigationController = UINavigationController(rootViewController: photoFilterController)
        
        mediaPickerManager.dismissImagePickerController(animated: true) { 
            self.present(navigationController, animated: true, completion: nil)
        }
        
    }
}

// MARK: - Navigation
extension PhotoListController {
    
    func setupNavigationBar() {
        // TODO: Implement location sorting
        let sortTagsButton = UIBarButtonItem(title: "Tags", style: .plain, target: self, action: #selector(PhotoListController.presentSortController))
        navigationItem.setRightBarButtonItems([sortTagsButton], animated: true)
        
        // Cancel editing button for photo deletion
        navigationItem.setLeftBarButtonItems([cancelEditingButton], animated: true)
        
        if !editingModeEnabled {
            cancelEditingButton.tintColor = UIColor.clear
            cancelEditingButton.isEnabled = false
        }
    }
    
    @objc private func presentSortController() {
        let tagDataSource = SortableDataSource<Tag>(fetchRequest: Tag.allTagsRequest, managedObjectContext: CoreDataController.sharedInstance.managedObjectContext)
        
        let sortItemSelector = SortItemSelector(sortItems: tagDataSource.results)
        
        let sortController = PhotoSortListController(dataSource: tagDataSource, sortItemSelector: sortItemSelector)
        sortController.onSortSelection = { checkedItems in
            
            // Check that checkedItems isn't empty, otherwise there's no need for a predicate
            if !checkedItems.isEmpty {
                var predicates = [NSPredicate]()
                for tag in checkedItems {
                    let predicate = NSPredicate(format: "%K CONTAINS %@", "tags.title", tag.title)
                    predicates.append(predicate)
                }

                let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
                // Use data source to perform fetch with predicate
                self.dataSource.performFetch(withPredicate: compoundPredicate)
            } else {
                // Reset to all photos in data store
                self.dataSource.performFetch(withPredicate: nil)
            }
        }
        
        let navigationController = UINavigationController(rootViewController: sortController)
        
        present(navigationController, animated: true, completion: nil)
        
    }
}

// MARK: - PhotoDeletionManagerDelegate

extension PhotoListController: PhotoDeletionManagerDelegate {
    func didTapDelete(atRow row: Int) {
        let indexPath = IndexPath(row: row, section: 0)
        print("The indexPath was calculated as: \(indexPath)")
        let photo = dataSource.fetchedResultsController.object(at: indexPath)
        
        // TODO: Delete here and save?
        alertForPhotoDeletion(photo: photo)
    }
    // MARK: Ask user for photo deletion confirmation
    private func alertForPhotoDeletion(photo: NSManagedObject) {
        let delete = UIAlertAction(title: "Delete", style: .default) { (action) in
            CoreDataController.sharedInstance.managedObjectContext.delete(photo)
            CoreDataController.sharedInstance.saveContext()
        }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        displayAlert(withMessage: "Delete photo?", title: "", actions: [delete, cancel])
    }
}

// MARK: - Photo selection

extension PhotoListController: UIGestureRecognizerDelegate {
    
    func enableLongPressDeletion() {
        let lpgr = UILongPressGestureRecognizer(target: self, action: #selector(PhotoListController.presentDeletion(gestureRecognizer:)))
        lpgr.minimumPressDuration = 1
        lpgr.delaysTouchesBegan = true
        lpgr.delegate = self
        self.collectionView.addGestureRecognizer(lpgr)
    }
    
    func presentDeletion(gestureRecognizer: UILongPressGestureRecognizer) {
        guard gestureRecognizer.state == .began else {
            return
        }
        
        // Make deletion button visible on all visible cells
        toggleCellDeletionButton(visible: true)
        
        // Enable editing mode to start animating ALL cells (both visible and not visible)
        editingModeEnabled = true
    }
    
    func toggleCellDeletionButton(visible: Bool) {
        for cell in collectionView.visibleCells as! [PhotoCell] {
            cell.deleteButton.isHidden = !visible
        }
    }
    
    // Tapping Cancel in Nav Bar
    func hideDeletion() {
        editingModeEnabled = false
    }
    
}

// MARK: - UICollectionViewDelegate

extension PhotoListController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        toggleCellAnimation(cell: cell)

    }
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        toggleCellAnimation(cell: cell)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print(indexPath)
    }
    
    private func toggleCellAnimation(cell: UICollectionViewCell) {
        if editingModeEnabled {
            CellAnimator.startWiggling(view: cell)
            (cell as! PhotoCell).deleteButton.isHidden = false
        } else {
            CellAnimator.stopWiggling(view: cell)
            (cell as! PhotoCell).deleteButton.isHidden = true
        }
    }
}
























