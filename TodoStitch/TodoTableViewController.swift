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
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        if !(stitchClient.auth.isLoggedIn) {
            self.performSegue(withIdentifier: "toLogin", sender: self)
        } else {
            LoginViewController.provider = stitchClient.auth.currentUser?.loggedInProviderType
        }
        mongoClient = stitchClient.serviceClient(fromFactory: remoteMongoClientFactory, withName: "mongodb-atlas")
        itemsCollection = mongoClient?.db("todo").collection("items")
        
        self.tableView.allowsMultipleSelectionDuringEditing = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getTasks()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    //////////////////////////////////////////////////////////////////////////////////////
    // MARK: Stitch CRUD
    //                          STITCH CRUD METHODS
    //
    //////////////////////////////////////////////////////////////////////////////////////
    func getTasks() {
        itemsCollection?.find().asArray({ result in
            switch result {
            case .success(let result):
                self.items = result
                DispatchQueue.main.async{
                    self.tableView.reloadData()
                }
            case .failure(let error):
                print("Error in finding documents: \(error)")
            }
        })
    }
    func addTask(taskName: String) {
        var itemDoc = Document()
        itemDoc["name"] = taskName
        itemDoc["owner_name"] = stitchClient.auth.currentUser?.profile.name! as! String
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
    
    
    //////////////////////////////////////////////////////////////////////////////////////
    // MARK: UI Methods
    //                                  UI METHODS
    //
    //////////////////////////////////////////////////////////////////////////////////////
    @IBAction func logoutPressed(_ sender: Any) {
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
            textField.placeholder = "Buy Groceries..."
        })
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteTaskAtRow(row: indexPath.row)
//        } else if editingStyle == .insert {
//            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }
    
    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
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

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
