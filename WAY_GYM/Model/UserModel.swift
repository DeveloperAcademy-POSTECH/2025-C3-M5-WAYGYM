//
//  UserModel.swift
//  Ch3Personal
//
//  Created by 이주현 on 5/30/25.
//

import Foundation

struct UserModel {
    var id: UUID
    
//    var totalDistance: Double // Minion
//    var totalCaptureArea: Double // Weapon
    var runRecords: [RunRecordModel]
    
    init(id: UUID, runRecords: [RunRecordModel]) {
            self.id = id
            self.runRecords = runRecords
//            self.totalDistance = runRecords.map { $0.totalDistance }.reduce(0, +)
//            self.totalCaptureArea = runRecords.map { $0.capturedAreaValue }.reduce(0, +)
        }
}

//extension UserModel {
//    var totalDistanceCalculated: Double {
//        runRecords.map { $0.totalDistance }.reduce(0, +)
//    }
//
//    var totalCaptureAreaCalculated: Double {
//        runRecords.map { $0.capturedAreaValue }.reduce(0, +)
//    }
//}
