//
//  ImagePreprocessingTool.swift
//  SudokuSolution
//
//  Created by 鲁成龙 on 13.05.2025.
//

import Foundation
import UIKit
import CoreImage
import Vision
import SwifterSwift


class ImagePreprocessingTool {
    
    static func preprocessImage(_ image: UIImage, completion: @escaping (UIImage, VNRectangleObservation) -> Void) {
        DispatchQueue.global().async {
            guard let ciImage = trunToCIImage(image) else {
                return
            }

            guard let grayCIImage = grayscale(ciImage) else {
                return
            }

            guard let blurredCIImage = gaussianBlur(grayCIImage) else {
                return
            }
            
            detectSudokuGridCorners(image: blurredCIImage) { observation in
                guard let observation = observation else {
                    print("Sudoku grid not detected.")
                    // 可以选择继续处理未校正的图像，或提示用户
                    // let imageToProcess = blurredCIImage // 使用未校正的
                    return
                }
                if let dewarpedCIImage = correctPerspective(image: blurredCIImage, rectangleObservation: observation) {
                    if let cleanedBinaryImage = morphology(image: dewarpedCIImage, radius: 1, operation: "open") {
                        let finalImage = UIImage.init(ciImage: cleanedBinaryImage)
                        DispatchQueue.main.async {
                            completion(finalImage, observation)
                        }
                    }
                }
            }
        }
    }
    
    //形态学操作 (Morphological Operations - 可选，在二值化后):用于清理二值化图像。例如，去除小的噪点 (Opening) 或连接数字中断的笔画 (Closing)。
    static func morphology(image: CIImage, radius: Float = 1.0, operation: String = "open") -> CIImage? {
        let erodeFilter = CIFilter(name: "CIMorphologyMinimum")
        erodeFilter?.setValue(image, forKey: kCIInputImageKey)
        erodeFilter?.setValue(radius, forKey: kCIInputRadiusKey)
        guard let eroded = erodeFilter?.outputImage else { return nil }

        let dilateFilter = CIFilter(name: "CIMorphologyMaximum")
        dilateFilter?.setValue(image, forKey: kCIInputImageKey)
        dilateFilter?.setValue(radius, forKey: kCIInputRadiusKey)
        guard let dilated = dilateFilter?.outputImage else { return nil }

        if operation == "open" {
            dilateFilter?.setValue(eroded, forKey: kCIInputImageKey)
            return dilateFilter?.outputImage
        } else if operation == "close" {
            erodeFilter?.setValue(dilated, forKey: kCIInputImageKey)
            return erodeFilter?.outputImage
        } else if operation == "erode" {
             return eroded
        } else if operation == "dilate" {
             return dilated
        }
        return image // No operation
    }
    
    //应用透视滤镜
    static func correctPerspective(image: CIImage, rectangleObservation: VNRectangleObservation) -> CIImage? {
        let imageSize = image.extent.size

        // 转换 Vision 归一化坐标 (左下原点) 到 Core Image 像素坐标 (左上原点)
        let topLeft = VNImagePointForNormalizedPoint(rectangleObservation.topLeft, Int(imageSize.width), Int(imageSize.height))
        let topRight = VNImagePointForNormalizedPoint(rectangleObservation.topRight, Int(imageSize.width), Int(imageSize.height))
        let bottomLeft = VNImagePointForNormalizedPoint(rectangleObservation.bottomLeft, Int(imageSize.width), Int(imageSize.height))
        let bottomRight = VNImagePointForNormalizedPoint(rectangleObservation.bottomRight, Int(imageSize.width), Int(imageSize.height))

        // Core Image 坐标系 Y 轴与 Vision 相反
        func ciPoint(_ point: CGPoint) -> CIVector {
            return CIVector(x: point.x, y: point.y)
        }

        let filter = CIFilter(name: "CIPerspectiveCorrection")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(ciPoint(topLeft), forKey: "inputTopLeft")
        filter?.setValue(ciPoint(topRight), forKey: "inputTopRight")
        filter?.setValue(ciPoint(bottomLeft), forKey: "inputBottomLeft")
        filter?.setValue(ciPoint(bottomRight), forKey: "inputBottomRight")

        return filter?.outputImage
    }
    
    //透视校正
    static func detectSudokuGridCorners(image: CIImage, completion: @escaping (VNRectangleObservation?) -> Void) {
        let request = VNDetectRectanglesRequest { (request, error) in
            guard error == nil, let observations = request.results as? [VNRectangleObservation] else {
                completion(nil)
                return
            }
            // 通常数独是最大或最主要的矩形，可以根据面积、置信度筛选
            // 这里简单取第一个，你可能需要更复杂的筛选逻辑
            completion(observations.first)
        }
        // 可以配置参数，如最小尺寸、最大数量、宽高比等
        request.minimumAspectRatio = VNAspectRatio(0.8) // 接近正方形
        request.maximumAspectRatio = VNAspectRatio(1.2)
        request.minimumSize = Float(0.3) // 占图像比例至少30%
        request.maximumObservations = 1 // 假设只有一个主要数独

        // 需要 VNImageRequestHandler
        // 注意 Vision 的坐标系 (原点左下角，归一化)
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform rectangle detection: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    //高斯模糊降噪
    static func gaussianBlur(_ image: CIImage, radius: Float = 0.7) -> CIImage? {
        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(radius, forKey: kCIInputRadiusKey)  // 半径需要调试，0.5-1.5 可能是起点
        return filter?.outputImage
    }

    //灰度
    static func grayscale(_ image: CIImage) -> CIImage? {
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(0.0, forKey: kCIInputSaturationKey)
        filter?.setValue(1.1, forKey: kCIInputContrastKey)  // 可选：同时稍微增加对比度
        return filter?.outputImage
    }

    //转换为CIImage
    static func trunToCIImage(_ image: UIImage) -> CIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let inputCIImage = CIImage(cgImage: cgImage)
        return inputCIImage
    }
}
