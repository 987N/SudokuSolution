//
//  Item.swift
//  SudokuSolution
//
//  Created by 鲁成龙 on 13.05.2025.
//

import Foundation
import UIKit

public struct SudokuLocation {
    let x: Int
    let y: Int
}
    

public class SudokuItem {
    let location: SudokuLocation
    var number: Int?
    var textField: UITextField?
    
    init(location: SudokuLocation, number: Int? = nil, textField: UITextField? = nil) {
        self.location = location
        self.number = number
        self.textField = textField
    }
}
