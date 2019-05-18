//
//  ViewController.swift
//  CatVsDog
//
//  Created by Alex Nadein on 5/18/19.
//  Copyright © 2019 Alex Nadein. All rights reserved.
//

import UIKit
import CoreML
import Vision
import ImageIO

class ViewController: UIViewController {
  
  // MARK: - Outlets
  @IBOutlet private weak var imageView: UIImageView!
  @IBOutlet private weak var cameraButton: UIBarButtonItem!
  @IBOutlet private weak var classificationLabel: UILabel!

  // MARK: - Image Classification
  lazy var classificationRequest: VNCoreMLRequest = {
    do {
      let model = try VNCoreMLModel(for: CatVsDogImageClassifier().model)
      
      let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
        self?.processClassifications(for: request, error: error)
      })
      request.imageCropAndScaleOption = .centerCrop
      return request
    }
    catch {
      fatalError("Failed to load Vision ML model: \(error)")
    }
  }()
  
  func updateClassifications(for image: UIImage) {
    classificationLabel.text = "Classifying..."
    
    let orientation = CGImagePropertyOrientation(image.imageOrientation)
    guard let ciImage = CIImage(image: image) else { fatalError("Unable to create \(CIImage.self) from \(image).") }
    
    DispatchQueue.global(qos: .userInitiated).async {
      let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
      do {
        try handler.perform([self.classificationRequest])
      }
      catch {
        print("Failed to perform classification.\n\(error.localizedDescription)")
      }
    }
  }
  
  /// Updates the UI with the results of the classification.
  func processClassifications(for request: VNRequest, error: Error?) {
    DispatchQueue.main.async {
      guard let results = request.results else {
        self.classificationLabel.text = "Unable to classify image.\n\(error!.localizedDescription)"
        return
      }

      let classifications = results as! [VNClassificationObservation]
      
      if classifications.isEmpty {
        self.classificationLabel.text = "Nothing recognized."
      }
      else {
        let topClassifications = classifications.prefix(2)
        let descriptions = topClassifications.map { classification in
          return String(format: "  (%.2f) %@", classification.confidence, classification.identifier)
        }
        self.classificationLabel.text = "Classification:\n" + descriptions.joined(separator: "\n")
      }
    }
  }
  
  // MARK: - Photo Actions
  @IBAction func takePicture() {
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
      presentPhotoPicker(sourceType: .photoLibrary)
      return
    }
    
    let photoSourcePicker = UIAlertController()
    let takePhoto = UIAlertAction(title: "Take Photo", style: .default) { [unowned self] _ in
      self.presentPhotoPicker(sourceType: .camera)
    }
    let choosePhoto = UIAlertAction(title: "Choose Photo", style: .default) { [unowned self] _ in
      self.presentPhotoPicker(sourceType: .photoLibrary)
    }
    
    photoSourcePicker.addAction(takePhoto)
    photoSourcePicker.addAction(choosePhoto)
    photoSourcePicker.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    
    present(photoSourcePicker, animated: true)
  }
  
  func presentPhotoPicker(sourceType: UIImagePickerController.SourceType) {
    let picker = UIImagePickerController()
    picker.delegate = self
    picker.sourceType = sourceType
    present(picker, animated: true)
  }
}

// MARK: - UIImagePickerControllerDelegate
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

    picker.dismiss(animated: true)

    let image = info[UIImagePickerController.InfoKey.originalImage] as! UIImage
    imageView.image = image
    updateClassifications(for: image)
  }

}

