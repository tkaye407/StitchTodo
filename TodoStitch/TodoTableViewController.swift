//
//  TodoTableViewController.swift
//  TodoStitch
//
//  Created by Tyler Kaye on 9/10/18.
//  Copyright © 2018 Tyler Kaye. All rights reserved.
//

import UIKit
import GoogleSignIn
import FacebookCore
import FacebookLogin
import StitchCore
import StitchRemoteMongoDBService

class TodoTableViewController: UITableViewController {
    // Variables for Stitch CRUD
    private var items: [Document] = []
    private lazy var stitchClient = Stitch.defaultAppClient!
    private var mongoClient: RemoteMongoClient?
    private var itemsCollection: RemoteMongoCollection<Document>?
   
 
    //////////////////////////////////////////////////////////////////////////////////////
    // MARK: View Setup
    //                                  VIEW SETUP METHODS
    //
    //////////////////////////////////////////////////////////////////////////////////////
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.allowsMultipleSelectionDuringEditing = false
        
        // If stitch is currently not logged in --> segue back to the login page
        if !(stitchClient.auth.isLoggedIn) {
            self.performSegue(withIdentifier: "toLogin", sender: self)
        } else {
            // If stitch is logged in, let the LoginViewController know which provider is logged in
            LoginViewController.provider = stitchClient.auth.currentUser?.loggedInProviderType
        }
        
        // Set the stitch variables declared above for use below
        mongoClient = stitchClient.serviceClient(fromFactory: remoteMongoClientFactory, withName: "mongodb-atlas")
        itemsCollection = mongoClient?.db("todo").collection("items")
    }
    
    // In viewWillAppear call getTasks() to performa find() on the database
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getTasks()
    }
    
    
    //////////////////////////////////////////////////////////////////////////////////////
    // MARK: Stitch CRUD
    //                          STITCH Functionality
    //
    //////////////////////////////////////////////////////////////////////////////////////
    
    // Insert a new task to the database with the relevant information and then reload the data
    func addTask(taskName: String) {
        var itemDoc = Document()
        itemDoc["name"] = taskName
        
        // only necessary if we dont have access to their name (Facebook / Google)
        if let userName = stitchClient.auth.currentUser?.profile.name {
            itemDoc["owner_name"] = userName
        }
        itemDoc["owner_id"] = stitchClient.auth.currentUser!.id
        itemDoc["completed"] = false
        self.itemsCollection?.insertOne(itemDoc, {result in
            switch result {
            case .success(_):
                self.getTasks()
            case .failure(let error):
                print("Failed to insert document: \(error)")
            }
        })
    }
    
    // Read all of the items from the database and then reload the UI
    func getTasks() {
        itemsCollection?.find().asArray({ result in
            switch result {
            case .success(let results):
                // HERE IS HOW TO SORT
                self.items = results.sorted(by: {($0["name"] as! String) > ($1["name"] as! String)})

                DispatchQueue.main.async{
                    self.tableView.reloadData()
                }
            case .failure(let error):
                print("Error in finding documents: \(error)")
            }
        })
    }
    
    // Update the current task's name and then reload the data
    func updateTaskAtRow(row: Int, newTask: String) {
        var filter: Document = Document()
        filter["_id"] = (items[row])["_id"] as! ObjectId
        
        var update: Document = Document()
        update["$set"] = Document(["name": newTask])
        
        itemsCollection?.updateOne(filter: filter, update: update, {result in
            switch result {
            case .success(_):
                self.getTasks()
            case .failure(let error):
                print("Failed to update document: \(error)")
            }
        })
    }
    
    // Delete the current task from the database and then reload the data
    func deleteTaskAtRow(row: Int) {
        var filter: Document = Document()
        filter["_id"] = (items[row])["_id"] as! ObjectId
        itemsCollection?.deleteOne(filter, {result in
            switch result {
            case .success(_):
                self.getTasks()
            case .failure(let error):
                print("Failed to delete document: \(error)")
            }
        })
    }
    
    // Execute a stitch function call request
    func callCustomFunction(withName: String) {
        stitchClient.callFunction(withName: "getSecretValue", withArgs: ["args"], withRequestTimeout: 5.0)
        {(result: StitchResult<String>) in
            switch result {
            case .success(let stringResult):
                let secretAlert = UIAlertController(title: "Secret Message: \(stringResult)", message: "This secret was found using stitch values and functions", preferredStyle: .alert)
                secretAlert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                self.present(secretAlert, animated: true, completion: nil)
            case .failure(let error):
                print("Error retrieving String: \(String(describing: error))")
            }
        }
    }
    
    // Logout from Stitch and send the user back to the sign in page
    func logout() {
        stitchClient.auth.logout({result in
            switch result {
            case .success:
                if let prov = LoginViewController.provider {
                    switch prov {
                    case .google:
                        GIDSignIn.sharedInstance().signOut()
                    case .facebook:
                        LoginManager().logOut()
                    default:
                        break
                    }
                }
                self.performSegue(withIdentifier: "toLogin", sender: self)
            case .failure(let error):
                print("Failed to logout of stitch due to error: \(error)")
                break
            }
        })
    }
    
    
    //////////////////////////////////////////////////////////////////////////////////////
    // MARK: UI Methods
    //                                  UI METHODS
    //
    //////////////////////////////////////////////////////////////////////////////////////
    @IBAction func callFunction(_ sender: Any) {
        callCustomFunction(withName: "secretFunction")
    }
    
    @IBAction func logoutPressed(_ sender: Any) {
        logout()
    }
    
    @IBAction func addItemPressed(_ sender: Any) {
        let alertController = UIAlertController(title: "New Task", message: "Enter Task Description", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: "Create", style: .default, handler: {
            alert -> Void in
            let taskName = alertController.textFields![0] as UITextField
            if taskName.text != "" {
                self.addTask(taskName: taskName.text!)
            } else {
                let errorAlert = UIAlertController(title: "Error", message: "Please input a task name", preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: {
                    alert -> Void in
                    self.present(alertController, animated: true, completion: nil)
                }))
                self.present(errorAlert, animated: true, completion: nil)
            }
        }))
        
        alertController.addTextField(configurationHandler: { (textField) -> Void in
            textField.placeholder = "Buy Groceries..."
        })
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    
    //////////////////////////////////////////////////////////////////////////////////////
    // MARK: - Tableview
    //                                 TABLEVIEW METHODS
    //
    //////////////////////////////////////////////////////////////////////////////////////
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "todoItemCell", for: indexPath)
        let currItem: Document = items[indexPath.row]
        cell.textLabel?.text = currItem["name"] as? String
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let alertController = UIAlertController(title: "Update Task", message: "Enter Updated Task Description", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: "Update", style: .default, handler: {
            alert -> Void in
            let taskName = alertController.textFields![0] as UITextField
            if taskName.text != "" {
                self.updateTaskAtRow(row: indexPath.row, newTask: taskName.text!)
            } else {
                let errorAlert = UIAlertController(title: "Error", message: "Please input a task name", preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: {
                    alert -> Void in
                    self.present(alertController, animated: true, completion: nil)
                }))
                self.present(errorAlert, animated: true, completion: nil)
            }
        }))
        
        alertController.addTextField(configurationHandler: { (textField) -> Void in
            let doc = self.items[indexPath.row]
            textField.placeholder = doc["name"] as! String ?? "Groceries..."
        })
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteTaskAtRow(row: indexPath.row)
        }
    }

}
