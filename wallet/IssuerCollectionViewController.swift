//
//  IssuerCollectionViewController.swift
//  wallet
//
//  Created by Chris Downie on 10/11/16.
//  Copyright © 2016 Learning Machine, Inc. All rights reserved.
//

import UIKit
import BlockchainCertificates

private let reuseIdentifier = "Cell"
private let segueToViewIssuer = "ShowIssuerDetail"

class IssuerCollectionViewController: UICollectionViewController {
    private let issuersArchiveURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Issuers")
    private let certificatesDirectory = Paths.certificatesDirectory
    
    // TODO: Should probably be AttributedIssuer, once I make up that model.
    var managedIssuers = [ManagedIssuer]()
    var certificates = [Certificate]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Set up the Collection View
        let cellNib = UINib(nibName: "IssuerCollectionViewCell", bundle: nil)
        self.collectionView?.register(cellNib, forCellWithReuseIdentifier: reuseIdentifier)
        self.collectionView?.delegate = self

        // Style this bad boy
        self.navigationController?.navigationBar.barTintColor = Colors.translucentBrandColor
        self.navigationController?.navigationBar.tintColor = Colors.tintColor
        
        // Load any existing issuers.
        loadIssuers(shouldReloadCollection: false)
        loadCertificates(shouldReloadCollection: false)
        reloadCollectionView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // TODO: this should be more nuanced. Child view controllers can delete the underlying data. So, for now, just reload all the data.
//        loadIssuers(shouldReloadCollection: false)
        loadCertificates()
//        reloadCollectionView()
    }

    
    // MARK: - Actions
    @IBAction func accountTapped(_ sender: UIBarButtonItem) {
        let controller = AccountViewController()
        present(controller, animated: true, completion: nil)
    }
    
    @IBAction func addButtonTapped(_ sender: UIBarButtonItem) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alertController.addAction(UIAlertAction(title: "Add Issuer", style: .default, handler: { [weak self] _ in
            self?.showAddIssuerFlow()
        }))
        
        alertController.addAction(UIAlertAction(title: "Import Certificate from File", style: .default, handler: { [weak self] _ in
            let controller = UIDocumentPickerViewController(documentTypes: ["public.json"], in: .import)
            controller.delegate = self
            controller.modalPresentationStyle = .formSheet
            
            self?.present(controller, animated: true, completion: nil)
        }))
        
        alertController.addAction(UIAlertAction(title: "Import Certificate from URL", style: .default, handler: { [weak self] _ in
            let urlPrompt = UIAlertController(title: nil, message: "What's the URL of the certificate?", preferredStyle: .alert)
            urlPrompt.addTextField(configurationHandler: { (textField) in
                textField.placeholder = "URL"
            })
            
            urlPrompt.addAction(UIAlertAction(title: "Import", style: .default, handler: { (_) in
                guard let urlField = urlPrompt.textFields?.first,
                    let trimmedText = urlField.text?.trimmingCharacters(in: CharacterSet.whitespaces),
                    let url = URL(string: trimmedText) else {
                        return
                }
                
                self?.add(certificateURL: url)
            }))
            
            self?.present(urlPrompt, animated: true, completion: nil)
        }))
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(alertController, animated: true, completion: nil)
    }
    
    // MARK: UICollectionViewDataSource
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return managedIssuers.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! IssuerCollectionViewCell

        let managedIssuer = managedIssuers[indexPath.item]
        guard let issuer = managedIssuer.issuer else {
            cell.titleLabel.text = "Missing issuer"
            return cell
        }
        
        cell.imageView.image = UIImage(data: issuer.image)
        cell.titleLabel.text = issuer.name
        cell.certificateCount = certificates.reduce(0, { (count, certificate) -> Int in
            if certificate.issuer.id == issuer.id {
                return count + 1
            }
            return count
        })
        
        cell.layer.masksToBounds = false
        cell.layer.shadowOffset = CGSize(width: 0, height: 3)
        cell.layer.shadowColor = UIColor.black.cgColor
        cell.layer.shadowOpacity = 0.4
        cell.layer.shadowRadius = 8
    
        return cell
    }
    
    // MARK: Issuer handling
    func reloadCollectionView() {
        OperationQueue.main.addOperation {
            self.collectionView?.reloadData()
        }
    }
    
    func loadIssuers(shouldReloadCollection : Bool = true) {
        managedIssuers = NSKeyedUnarchiver.unarchiveObject(withFile: issuersArchiveURL.path) as? [ManagedIssuer] ?? []
        
        if shouldReloadCollection {
            reloadCollectionView()
        }
    }
    
    func saveIssuers() {
        NSKeyedArchiver.archiveRootObject(managedIssuers, toFile: issuersArchiveURL.path)
    }
    
    func add(issuer: Issuer) {
        let managedIssuer = ManagedIssuer()
        managedIssuer.manage(issuer: issuer) { [weak self] success in
            self?.reloadCollectionView()
            self?.saveIssuers()
            print("Got identity from raw issuer \(success)")
        }
        
        add(managedIssuer: managedIssuer)
    }
    
    func add(managedIssuer: ManagedIssuer) {
        managedIssuers.append(managedIssuer)
        saveIssuers()
        OperationQueue.main.addOperation {
            self.collectionView?.reloadData()
        }
    }
    
    // MARK: Certificate handling
    func loadCertificates(shouldReloadCollection : Bool = true) {
        certificates = []
        
        let existingFiles = try? FileManager.default.contentsOfDirectory(at: certificatesDirectory, includingPropertiesForKeys: nil, options: [])
        let files = existingFiles ?? []
        
        let loadedCertificates : [Certificate] = files.flatMap { fileURL in
            guard let data = try? Data(contentsOf: fileURL) else {
                return nil
            }
            return try? CertificateParser.parse(data: data)
        }
        
        loadedCertificates.forEach { certificate in
            self.add(certificate: certificate)
        }
        
        if shouldReloadCollection {
            reloadCollectionView()
        }
    }
    
    func saveCertificates() {
        // Make sure the `certificatesDirectory` exists by trying to create it every time.
        try? FileManager.default.createDirectory(at: certificatesDirectory, withIntermediateDirectories: false, attributes: nil)
        
        for certificate in certificates {
            let fileURL = certificatesDirectory.appendingPathComponent(certificate.assertion.uid)
            do {
                try certificate.file.write(to: fileURL)
            } catch {
                print("ERROR: Couldn't save \(certificate.title) to \(fileURL): \(error)")
                dump(certificate)
                // TODO: Remove this fatalError call. It's really just in here during development.
                fatalError()
            }
        }
    }
    
    func add(certificate: Certificate) {
        let isKnownIssuer = managedIssuers.contains(where: { (existingManager) -> Bool in
            return existingManager.issuer?.id == certificate.issuer.id
        })
        
        if !isKnownIssuer {
            add(issuer: certificate.issuer)
        }
        
        certificates.append(certificate)
        saveCertificates()
    }
    
    func add(certificateURL: URL) {
        var components = URLComponents(url: certificateURL, resolvingAgainstBaseURL: false)
        let formatQueryItem = URLQueryItem(name: "format", value: "json")
        
        if components?.queryItems == nil {
            components?.queryItems = [
                formatQueryItem
            ]
        } else {
            components?.queryItems?.append(formatQueryItem)
        }
        
        var data: Data? = nil
        if let dataURL = components?.url {
            data = try? Data(contentsOf: dataURL)
        }
        
        if let data = data,
            let certificate = try? CertificateParser.parse(data: data) {
            add(certificate: certificate)
        } else {
            // TODO: Show some alert saying that this URL isn't a valid certifiate url.
        }
    }
    
    func showAddIssuerFlow(identificationURL: URL? = nil, nonce : String? = nil) {
        let controller = AddIssuerViewController(identificationURL: identificationURL, nonce: nonce)
        controller.delegate = self
        
        present(controller, animated: true) {
            controller.autoSubmitIfPossible()
        }
    }
}


extension IssuerCollectionViewController { //  : UICollectionViewDelegate
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let managedIssuer = managedIssuers[indexPath.item]
        let issuerController = IssuerTableViewController()
        
        issuerController.managedIssuer = managedIssuer
        issuerController.certificates = certificates.filter { certificate in
            return managedIssuer.issuer != nil && certificate.issuer.id == managedIssuer.issuer!.id
        }
        
        self.navigationController?.pushViewController(issuerController, animated: true)
    }
}

extension IssuerCollectionViewController : AddIssuerViewControllerDelegate {
    func added(managedIssuer: ManagedIssuer) {
        if managedIssuer.issuer != nil {
            self.add(managedIssuer: managedIssuer)
        } else {
            print("Something weird -- delegate called with nil issuer. \(#function)")
        }
    }
}

// MARK: Functions from the open source.
extension IssuerCollectionViewController {
    func importCertificate(from data: Data?) {
        guard let data = data else {
            let alertController = UIAlertController(title: "Couldn't read file", message: "Something went wrong trying to open the file.", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alertController] action in
                alertController?.dismiss(animated: true, completion: nil)
                }))
            present(alertController, animated: true, completion: nil)
            return
        }
        guard let certificate = try? CertificateParser.parse(data: data) else {
            let alertController = UIAlertController(title: "Invalid Certificate", message: "That doesn't appear to be a valid Certificate file.", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alertController] action in
                alertController?.dismiss(animated: true, completion: nil)
                }))
            present(alertController, animated: true, completion: nil)
            return
        }
        
        // At this point, data is totally a valid certificate. Let's save that to the documents directory.
        add(certificate: certificate)
//        
//        let filename = certificate.assertion.uid
//        let success = save(certificateData: data, withFilename: filename)
//        let isCertificateInList = certificates.contains(where: { $0.assertion.uid == certificate.assertion.uid })
//        
//        if isCertificateInList {
//            let alertController = UIAlertController(title: "File already imported", message: "You've already imported that file.", preferredStyle: .alert)
//            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
//            present(alertController, animated: true, completion: nil)
//        } else if !success {
//            let alertController = UIAlertController(title: "Failed to save file", message: "Try importing the file again. ", preferredStyle: .alert)
//            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
//            present(alertController, animated: true, completion: nil)
//        } else {
//            certificates.append(certificate)
//            
//            // Issue #20: We should do an insert animation rather than a full table reload.
//            // https://github.com/blockchain-certificates/cert-wallet/issues/20
//            tableView.reloadData()
//        }
    }
}

extension IssuerCollectionViewController : UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        let data = try? Data(contentsOf: url)
        
        importCertificate(from: data)
    }
}



// MARK: UICollectionViewDelegate

/*
 // Uncomment this method to specify if the specified item should be highlighted during tracking
 override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
 return true
 }
 */

/*
 // Uncomment this method to specify if the specified item should be selected
 override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
 return true
 }
 */

/*
 // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
 override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
 return false
 }
 
 override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
 return false
 }
 
 override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
 
 }
 */
