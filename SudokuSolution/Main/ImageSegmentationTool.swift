//
//  ImageSegmentationTool.swift
//  SudokuSolution
//
//  Created by 鲁成龙 on 13.05.2025.
//

import Foundation
import UIKit
import CoreImage
import Vision

class ImageSegmentationTool {
    
    static func segmentation(_ image: UIImage, completion: @escaping ([[SudokuItem]]) -> Void){
        DispatchQueue.global().async {
            let context = CIContext()
            guard let cgImage = context.createCGImage(image.ciImage!, from: image.ciImage!.extent) else {
                return
            }
            let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            
            var results: [[SudokuItem]] = []
            
            for y in 0..<9 {
                var cows: [SudokuItem] = []
                for x in 0..<9 {
                    let item = SudokuItem(location: .init(x: x, y: y))
                    cows.append(item)
                }
                results.append(cows)
            }
            
            let textRecognitionRequest = VNRecognizeTextRequest.init { request, error in
                if let error = error {
                    print("文本识别错误: \(error.localizedDescription)")
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    print("未能获取到 VNRecognizedTextObservation")
                    return
                }
                handleRecognizedText(observations, items: results, completion: completion)
            }
            //识别等级
            textRecognitionRequest.recognitionLevel = .accurate
            //禁用语言校正
            textRecognitionRequest.usesLanguageCorrection = false
            //设置识别区域
            textRecognitionRequest.customWords = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
            
            do {
                try imageRequestHandler.perform([textRecognitionRequest])
            } catch {
                print("执行文本识别请求失败: \(error.localizedDescription)")
            }
        }
    }
    
    static func handleRecognizedText(_ observations: [VNRecognizedTextObservation], items:[[SudokuItem]], completion: @escaping ([[SudokuItem]]) -> Void) {
        for observation in observations {
            // 获取置信度最高的候选文本 (通常我们只需要第一个)
            guard let topCandidate = observation.topCandidates(1).first else { continue }

            let recognizedString = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)

            // 因为我们只关心单个数字，并且已经设置了 customWords
            // 我们可以直接检查这个字符串是否是我们期望的数字
            if recognizedString.count == 1 && "123456789".contains(recognizedString) {
                print("识别到的数字: \(recognizedString) (置信度: \(topCandidate.confidence))")
                
                // 为了更准确地确定数字属于哪个单元格，使用 boundingBox 的中心点通常比使用其原点 (origin) 更鲁棒。
                let normalizedCenterX = observation.boundingBox.origin.x + (observation.boundingBox.width / 2.0)
                let normalizedCenterY = observation.boundingBox.origin.y + (observation.boundingBox.height / 2.0) // 这是从底部算起的中心Y
                
                // 计算列 (column)
                // 归一化坐标乘以9，然后取整，得到0-8的列索引
                let col = Int(floor(normalizedCenterX * 9.0))

                // 计算行 (row)
                // 因为 normalizedCenterY 是从底部开始的 (0.0 代表图像底部, 1.0 代表图像顶部)
                // 而我们通常的二维数组或数独逻辑中，第0行在最上面。
                // 所以我们需要转换一下：(1.0 - normalizedCenterY) 就变成了从顶部开始的归一化Y坐标。
                let normalizedYFromTop = 1.0 - normalizedCenterY
                let row = Int(floor(normalizedYFromTop * 9.0))
                
                // 基本的边界检查
                if row >= 0 && row < 9 && col >= 0 && col < 9 {
                    items[row][col].number = Int(recognizedString)
                } else {
                    // 如果计算出的行列超出0-8的范围，说明这个识别结果可能在网格边缘或外部，或者计算有误
                    print("警告: 数字 '\(recognizedString)' 计算出的位置 [\(row)][\(col)] 超出数独网格边界。Normalized BBox Center: (\(normalizedCenterX), \(normalizedCenterY))")
                }
                
            } else if !recognizedString.isEmpty {
                // 可能是识别到了多个字符或者非期望字符，根据情况处理或忽略
                print("识别到非期望文本: '\(recognizedString)' (置信度: \(topCandidate.confidence))")
            }
        }
        DispatchQueue.main.async {
            completion(items)
        }
    }
}
