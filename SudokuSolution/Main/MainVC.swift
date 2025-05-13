//
//  MainVC.swift
//  SudokuSolution
//
//  Created by 鲁成龙 on 13.05.2025.
//

import SnapKit
import UIKit

class MainVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {

    @IBOutlet weak var getImageButton: UIButton!
    @IBOutlet weak var solverButton: UIButton!
    @IBOutlet weak var tipLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    
    var originImage: UIImage!
    var finalImage: UIImage!
    var sudokuView: UIView!
    var sudokuData: [[SudokuItem]]?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.activityIndicator.isHidden = true
    }
    
    @IBAction func getImageAction(_ sender: Any) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let cameraAction = UIAlertAction(title: "相机", style: .default) { _ in
            self.cameraAction()
        }
        let photoAction = UIAlertAction(title: "相册", style: .default) { _ in
            self.photoAction()
        }
        alert.addAction(cameraAction)
        alert.addAction(photoAction)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
    
    func cameraAction() {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .camera
        imagePicker.delegate = self
        imagePicker.cameraCaptureMode = .photo
        imagePicker.showsCameraControls = true
        present(imagePicker, animated: true)
    }
    
    func photoAction() {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self
        present(imagePicker, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage {
            originImage = image.fixOrientation()
            getImageButton.isHidden = true
            activityIndicator.isHidden = false
            activityIndicator.startAnimating()
            ImagePreprocessingTool.preprocessImage(originImage) { [unowned self] preprocessedImage, rectangleObservation in
                self.finalImage = preprocessedImage
                self.getSudokuItem();
            }
        }
    }
    
    @IBAction func soloverSudoku(_ sender: Any) {
        if !solverButton.isSelected {
            self.sudokuView.isUserInteractionEnabled = false
            let solver = SudokuSolver(board: self.sudokuData!)
            DispatchQueue.global().async {
                if solver.solve() {
                    // solver.board 现在包含了完整的解
                    // 你可以遍历 solver.board 更新你的 UI (UITextField)
                    DispatchQueue.main.async {
                        self.tipLabel.text = "数独已解决!, 尝试次数: \(solver.tryCount)"
                        for r in 0..<9 {
                            for c in 0..<9 {
                                if let number = solver.board[r][c].number {
                                    solver.board[r][c].textField?.text = "\(number)"
                                }
                            }
                        }
                        self.solverButton.setTitle("再来一次", for: .normal)
                        self.solverButton.isSelected = true
                    }
                } else {
                    print("此数独无解。")
                }
            }
        } else {
            self.solverButton.isSelected = false
            self.solverButton.setTitle("开始解算", for: .normal)
            tipLabel.text = "对照游戏，确定识别正确后即可解算"
            self.sudokuView.removeFromSuperview()
            self.sudokuView = nil
            self.sudokuData = nil
            self.getImageButton.isHidden = false
            self.solverButton.isHidden = true
            self.tipLabel.isHidden = true
        }
    }
    
    
    func getSudokuItem() {
        ImageSegmentationTool.segmentation(self.finalImage) { [unowned self] results in
            self.sudokuData = results
            self.initSudokuView()
        }
    }
    
    func initSudokuView() {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        let width = (view.width - 60) / 9
        let size = CGSize(width: width, height: width)
        let gap = 15.0
        sudokuView = UIView()
        sudokuView.backgroundColor = .clear
        view.addSubview(sudokuView)
        sudokuView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(100)
            make.leading.equalToSuperview().offset(15)
            make.trailing.equalToSuperview().offset(-15)
            make.height.equalTo(size.height * 9)
        }
        
        for row in sudokuData! {
            for item in row {
                let textField = UITextField()
                textField.backgroundColor = .clear
                textField.layer.borderWidth = 0.5
                textField.layer.borderColor = UIColor.black.cgColor
                if item.number != nil {
                    textField.text = "\(item.number!)"
                    textField.textColor = UIColor.gray
                } else {
                    textField.textColor = UIColor.red
                }
                textField.textAlignment = .center
                textField.font = .systemFont(ofSize: 15)
                textField.frame = CGRect(x: CGFloat(item.location.x) * width + CGFloat(item.location.x / 3) * gap,
                                         y: CGFloat(item.location.y) * width + CGFloat(item.location.y / 3) * gap,
                                         width: width,
                                         height: width)
                textField.keyboardType = .asciiCapableNumberPad
                textField.delegate = self
                item.textField = textField
                sudokuView.addSubview(textField)
            }
        }
        self.solverButton.isHidden = false
        self.tipLabel.isHidden = false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if let text = textField.text, let number = Int(text), number >= 1 && number <= 9 {
            for row in sudokuData! {
                for item in row {
                    if item.textField == textField {
                        item.number = number
                        textField.textColor = UIColor.gray
                        return
                    }
                }
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
}


extension UIImage {
    func fixOrientation() -> UIImage {
        if self.imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
}
