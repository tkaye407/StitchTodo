//
//  File.swift
//  TodoStitch
//
//  Created by Tyler Kaye on 9/13/18.
//  Copyright © 2018 Tyler Kaye. All rights reserved.
//

import Foundation
import StitchCore

struct TodoItem {
    
    struct Keys {
        static let objectIdKey  = "_id"
        static let nameKey      = "name"
        static let ownerNameKey = "owner_name"
        static let ownerIdKey   = "owner_id"
        static let dateKey      = "date_added"
        static let doneKey      = "done"
    }
    
    let objectID:  ObjectId
    let taskName:  String
    let ownerId:   String
    let ownerName: String
//    let dateAdded: Date
    let done:      Bool

    //MARK: - Init
    init?(document: Document) {
        
        guard   let objectID = document[Keys.objectIdKey] as? ObjectId,
                let tOwnerID  = document[Keys.ownerIdKey] as? String,
                let tName = document[Keys.nameKey] as? String else {
                return nil
        }
        self.objectID   = objectID
        self.taskName   = tName
        self.ownerId    = tOwnerID
//        self.dateAdded  = tDate
        self.done       = document[Keys.doneKey] as? Bool ?? false
        self.ownerName  = document[Keys.ownerNameKey] as? String ?? ""
    }
    
    public static func newDocumentForTask(taskName: String, done: Bool = false) -> Document {
        var doc = Document()
        doc[Keys.nameKey] = taskName
//        doc[Keys.dateKey] = Date()
        doc[Keys.doneKey] = done
        doc[Keys.ownerIdKey] = Stitch.defaultAppClient?.auth.currentUser?.id ?? ""
        doc[Keys.ownerNameKey] = Stitch.defaultAppClient?.auth.currentUser?.profile.name ?? ""
        return doc
    }
}


extension TodoItem: Comparable {
    public static func ==(lhs: TodoItem, rhs: TodoItem) -> Bool {
        return lhs.objectID.oid == rhs.objectID.oid
    }
    
    public static func < (lhs: TodoItem, rhs: TodoItem) -> Bool {
        return lhs.taskName < rhs.taskName
    }
}
