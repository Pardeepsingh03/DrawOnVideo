//
//  ViewController.swift
//  DrawOnVideoSample
//
//  Created by MBA-0019 on 07/09/23.
//

import UIKit
import AVFoundation
import PencilKit
import Photos
import CoreMedia
import CoreText
import Metal
import ACEDrawingView


class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, ACEDrawingViewDelegate {
    var player: AVPlayer?
       var playerLayer: AVPlayerLayer?
      // var drawingView: PKCanvasView?
       var exportSession: AVAssetExportSession?
    var drawingView: ACEDrawingView!
    let imagePicker = UIImagePickerController()
    var videoURL: URL?
    var drawingURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        print("starting")
       
        imagePicker.delegate = self
               
               // Check if the device supports picking videos
               if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                   imagePicker.sourceType = .photoLibrary
                   imagePicker.mediaTypes = ["public.movie"]
               }
        // Do any additional setup after loading the view.
//        guard let videoURL = Bundle.main.url(forResource: "horserun", withExtension: "mp4") else {
//                  return
//              }
       
    }
  
    @IBAction func pickVideoButtonPressed(_ sender: UIButton) {
           present(imagePicker, animated: true, completion: nil)
       }
    
    @IBAction func startDrawingButtonPressed(_ sender: UIButton) {
            // Start drawing on the video
      setupDrawingView()
        }
    @IBAction func addTextToImage(_ sender: UIButton){
       // addTextToVideo()
    }
    
    @IBAction func saveVideoWithDrawingsButtonPressed(_ sender: UIButton) {
          guard let videoURL = videoURL else {
              print("No video URL found.")
              return
          }
          
          guard let drawingView = drawingView else {
              print("No drawing view found.")
              return
          }
          
          // Capture the drawings from the ACEDrawingView
          if let drawingsImage = drawingView.image {
              // Merge drawings with the video frames and save the edited video
              
              saveVideoWithDrawings(videoURL: videoURL, drawingsImage: drawingsImage)
          }
      }

    func saveVideoWithDrawings(videoURL: URL, drawingsImage: UIImage) {
        // Create an AVAsset for the video
        let videoAsset = AVAsset(url: videoURL)
        
        // Create an AVAssetExportSession to export the edited video
        guard let exportSession = AVAssetExportSession(asset: videoAsset, presetName: AVAssetExportPresetHighestQuality) else {
            print("Failed to create export session.")
            return
        }
        
        // Specify the desired output URL for the edited video
        let outputURL = tempURL()
        
        // Create a video composition to overlay drawings
        let videoComposition = AVMutableVideoComposition()
        
        // Set the render size and frame duration based on the video asset
        if let videoTrack = videoAsset.tracks(withMediaType: .video).first {
            videoComposition.renderSize = videoTrack.naturalSize
            videoComposition.frameDuration = videoTrack.minFrameDuration
        }
        
        // Create a video layer instruction for the video track
        let videoLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoAsset.tracks(withMediaType: .video).first!)
        videoLayerInstruction.setTransform(videoAsset.preferredTransform, at: .zero)
        
        // Create a parent layer to hold both video and drawing layers
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: videoComposition.renderSize)
        
        // Add the video layer instruction to the parent layer
        parentLayer.addSublayer(CALayer(layer: videoLayerInstruction))
        
        // Create a drawing image layer
        let drawingImageLayer = CALayer()
        drawingImageLayer.contents = drawingsImage.cgImage
        drawingImageLayer.frame = CGRect(origin: .zero, size: videoComposition.renderSize)
        drawingImageLayer.masksToBounds = true
        parentLayer.addSublayer(drawingImageLayer)
        
        // Set the video composition's animationTool to the parent layer
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: parentLayer, in: parentLayer)
        
        // Create a video composition instruction
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: videoAsset.duration)
        
        // Add video and drawing layer instructions to the composition instruction
        instruction.layerInstructions = [videoLayerInstruction]
        
        // Add the composition instruction to the video composition
        videoComposition.instructions = [instruction]
        
        // Set the video composition for the export session
        exportSession.videoComposition = videoComposition
        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mp4
        
        // Export the video with drawings
        exportSession.exportAsynchronously {
            // Handle export completion or errors here
            switch exportSession.status {
            case .completed:
                print("Video with drawings saved successfully.")
                // You can access the saved video at `outputURL` for further use
               // print(outputURL)
                if let outputURL = exportSession.outputURL {
                                   print("Video with drawings saved to local files successfully at: \(outputURL)")
                                   // You can access the saved video at `outputURL` for further use.
                                   PHPhotoLibrary.shared().performChanges({
                                       PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
                                   }) { (saved, error) in
                                       if saved {
                                           print("Video saved to the photo library.")
                                       } else if let error = error {
                                           print("Error saving video to the photo library: \(error.localizedDescription)")
                                       }
                                   }
                               } else {
                                   print("Error: Output URL not found.")
                               }
                
            case .failed:
                if let error = exportSession.error {
                    print("Error exporting video: \(error.localizedDescription)")
                } else {
                    print("Error exporting video: Unknown error.")
                }
                
            case .cancelled:
                print("Export operation cancelled.")
                
            default:
                print("Export operation completed with an unexpected status.")
            }
        }
    }


    
    func setupDrawingView() {
        // Create an instance of ACEDrawingView and add it as a subview
        drawingView = ACEDrawingView(frame: playerLayer!.frame)
        drawingView?.delegate = self
        drawingView?.lineColor = UIColor.red
        drawingView?.lineWidth = 5.0
        view.addSubview(drawingView!)
        drawingView?.drawMode = .scale
    }
 
  
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let videoURL = info[UIImagePickerController.InfoKey.mediaURL] as? URL {
                // Set the selected video URL
                self.videoURL = videoURL
                
                // Initialize the AVPlayer and display the video
                player = AVPlayer(url: videoURL)
                playerLayer = AVPlayerLayer(player: player)
                playerLayer?.frame = CGRect(x: 50, y: 50, width: 300, height: 300)
                playerLayer?.videoGravity = .resizeAspectFill
                DispatchQueue.main.async {
                           self.view.layer.addSublayer(self.playerLayer!)
                           self.drawingView?.frame = self.playerLayer!.frame
                       }
                       player?.play()
            }
            
            dismiss(animated: true, completion: nil)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss(animated: true, completion: nil)
        }
 
    func tempURL() -> URL? {
        let directory = NSTemporaryDirectory() as NSString

        if directory != "" {
            let path = directory.appendingPathComponent(NSUUID().uuidString+".mp4")
            return URL(fileURLWithPath: path)
        }

        return nil
    }
}

