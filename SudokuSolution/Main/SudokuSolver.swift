//
//  File.swift
//  SudokuSolution
//
//  Created by 鲁成龙 on 13.05.2025.
//
import Foundation

class SudokuSolver {
    var board: [[SudokuItem]] // 初始化时传入你已部分填充的数独板
    
    var tryCount = 0

    init(board: [[SudokuItem]]) {
        self.board = board
    }

    func solve() -> Bool {
        tryCount+=1 // 统计尝试次数
        var emptyLocation = findEmptyLocationMRV()
        if emptyLocation == nil {
            emptyLocation = findEmptyLocation()
        }
        if emptyLocation == nil {
            return true // 没有空格了，数独已解决
        }
        
        let row = emptyLocation!.y
        let col = emptyLocation!.x
        print("solve() attempting cell: (\(row), \(col))")
        for numberToTry in 1...9 {
            if isSafe(row: row, col: col, number: numberToTry) {
                // 尝试填入数字
                board[row][col].number = numberToTry
                print("Trying number \(numberToTry) for cell (\(row), \(col))")
                // (可选) 更新对应的 textField?.text，如果需要实时显示
                DispatchQueue.main.async {
                    self.board[row][col].textField?.text = "\(numberToTry)"
                }
                // 递归求解
                if solve() {
                    return true // 找到解了
                }

                // 如果solve()返回false，说明基于numberToTry的后续路径无解，需要回溯
                board[row][col].number = nil // 恢复为空
                // (可选) 清空对应的 textField?.text
                DispatchQueue.main.async {
                    self.board[row][col].textField?.text = ""
                }
            }
        }
        return false // 这个空格尝试了1-9都无解
    }

    // 查找下一个空格（可以实现MRV等高级策略）
    // 简单版本：从上到下，从左到右查找第一个空格
    private func findEmptyLocation() -> SudokuLocation? {
        for r in 0..<9 {
            for c in 0..<9 {
                if board[r][c].number == nil {
                    return board[r][c].location
                }
            }
        }
        return nil
    }

    // (可选) 实现MRV策略的findEmptyLocation
    private func findEmptyLocationMRV() -> SudokuLocation? {
        var minRemainingValues = 10 // 比最大可能值9多1
        var bestLocation: SudokuLocation? = nil

        for r in 0..<9 {
            for c in 0..<9 {
                if board[r][c].number == nil {
                    var count = 0
                    for num in 1...9 {
                        if isSafe(row: r, col: c, number: num) {
                            count += 1
                        }
                    }
                    if count == 0 { // 如果某个空格一个数字都不能填，说明盘面已错，可以提前终止
                        return nil // 或者需要一个方式通知solve函数此路不通
                    }
                    if count < minRemainingValues {
                        minRemainingValues = count
                        bestLocation = board[r][c].location
                    }
                }
            }
        }
        return bestLocation // 可能仍是nil，如果所有格子都填了
    }


    // 检查在指定位置填入数字是否安全（符合数独规则）
    private func isSafe(row: Int, col: Int, number: Int) -> Bool {
        // 1. 检查行
        for c in 0..<9 {
            if board[row][c].number == number {
                return false
            }
        }

        // 2. 检查列
        for r in 0..<9 {
            if board[r][col].number == number {
                return false
            }
        }

        // 3. 检查 3x3 九宫格
        let boxStartRow = row - (row % 3)
        let boxStartCol = col - (col % 3)

        for r in 0..<3 {
            for c in 0..<3 {
                if board[boxStartRow + r][boxStartCol + c].number == number {
                    return false
                }
            }
        }
        return true // 都安全
    }
}
