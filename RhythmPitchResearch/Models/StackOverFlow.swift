import SwiftUI
import Foundation
import AVFoundation
import Accelerate

class StackOverflow {
    
    func testFFT() {
        do {
            //let fileURL = Bundle.main.url(forResource: "Example 1_SkyPad", withExtension: "mp3")!
            let fileURL = Bundle.main.url(forResource: "Example 1_SkyPad", withExtension: "wav")!
            let audioFile = try!  AVAudioFile(forReading: fileURL as URL)
            let frameCount = UInt32(audioFile.length)
            
            //let log2n = UInt(round(log2(Double(frameCount ))))
            let log2n = UInt(round(log2(Double(frameCount * UInt32(2.0 )))))
            let bufferSizePOT = Int(1 << log2n)
            
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(bufferSizePOT))!
            try! audioFile.read(into: buffer, frameCount:frameCount)
            
            // Not sure if AVAudioPCMBuffer zero initialises extra frames, so when in doubt...
            let leftFrames = buffer.floatChannelData![0]
            for i in Int(frameCount)..<Int(bufferSizePOT) {
                leftFrames[i] = 0
            }
            
            // Set up the transform
            let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))!
            
            // create packed real input
            var realp = [Float](repeating: 0, count: bufferSizePOT/2)
            var imagp = [Float](repeating: 0, count: bufferSizePOT/2)
            var output = DSPSplitComplex(realp: &realp, imagp: &imagp)
            
            leftFrames.withMemoryRebound(to: DSPComplex.self, capacity: bufferSizePOT / 2) {
                vDSP_ctoz($0, 2, &output, 1, UInt(bufferSizePOT / 2))
            }
            
            // Do the fast Fourier forward transform, packed input to packed output
            vDSP_fft_zrip(fftSetup, &output, 1, log2n, Int32(FFT_FORWARD))
            
            // you can calculate magnitude squared here, with care
            // as the first result is wrong! read up on packed formats
            var fft = [Float](repeating:0.0, count:Int(bufferSizePOT / 2))
            vDSP_zvmags(&output, 1, &fft, 1, vDSP_Length(bufferSizePOT / 2))
            
            // Release the setup
            vDSP_destroy_fftsetup(fftSetup)
        }
        catch let exception {
            print(exception.localizedDescription)
        }
    }
}
