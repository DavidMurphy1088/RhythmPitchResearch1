
//https://github.com/christopherhelf/Swift-FFT-Example/blob/master/README.md
//  Adapted From https://gerrybeauregard.wordpress.com/2013/01/28/using-apples-vdspaccelerate-fft/

//READ:: https://stackoverflow.com/questions/60120842/how-to-use-apples-accelerate-framework-in-swift-in-order-to-compute-the-fft-of

import Foundation
import Accelerate
import Foundation
import Accelerate
//
//var fft = FFT()
//
//let n = 512 // Should be power of two for the FFT
//let frequency1 = 4.0
//let phase1 = 0.0
//let amplitude1 = 8.0
//let seconds = 2.0
//let fps = Double(n)/seconds
//
//var sineWave = (0..<n).map {
//    amplitude1 * sin(2.0 * .pi / fps * Double($0) * frequency1 + phase1)
//}
//
//fft.calculate(sineWave, fps: fps)

class FFT {
    
    fileprivate func getFrequencies(_ N: Int, fps: Double) -> [Double] {
        // Create an Array with the Frequencies
        let freqs = (0..<N/2).map {
            fps/Double(N)*Double($0)
        }
        
        return freqs
    }
    
    func str(_ inVal:Double) -> String {
        return String(format: "%.3f", inVal)
    }

    fileprivate func generateBandPassFilter(_ freqs: [Double]) -> ([Double], Int, Int) {
        var minIdx = freqs.count+1
        var maxIdx = -1
        
        //print("  BandPass min,max:", freqs.min(), freqs.max(), self.lowerFreq, self.higherFreq)
        let bandPassFilter: [Double] = freqs.map {
            if ($0 >= self.lowerFreq && $0 <= self.higherFreq) {
                return 1.0
            } else {
                return 0.0
            }
        }
        
        for (i, element) in bandPassFilter.enumerated() {
            if (element == 1.0) {
                if(i<minIdx || minIdx == freqs.count+1) {
                    minIdx=i
                }
                if(i>maxIdx || maxIdx == -1) {
                    maxIdx=i
                }
            }
        }
        
        assert(maxIdx != -1)
        assert(minIdx != freqs.count+1)
        
        return (bandPassFilter, minIdx, maxIdx)
    }
    
    func calculate(_ audio:Audio, _ _values: [Double], publish:Bool, framesPerSecond: Double = 44100.0) {
        // ----------------------------------------------------------------
        // Copy of our input
        // ----------------------------------------------------------------
        let values1 = _values
        var values = values1  // need this to avoid error below
        
        // ----------------------------------------------------------------
        // Size Variables
        // ----------------------------------------------------------------
        let N = values.count
        let N2 = vDSP_Length(N/2)
        let LOG_N = vDSP_Length(log2(Float(values.count)))
        
        // ----------------------------------------------------------------
        // FFT & Variables Setup
        // ----------------------------------------------------------------
        let fftSetup: FFTSetupD = vDSP_create_fftsetupD(LOG_N, FFTRadix(kFFTRadix2))!
        
        // We need complex buffers in two different formats!
        var tempComplex : [DSPDoubleComplex] = [DSPDoubleComplex](repeating: DSPDoubleComplex(), count: N/2)
        
        var tempSplitComplexReal : [Double] = [Double](repeating: 0.0, count: N/2)
        var tempSplitComplexImag : [Double] = [Double](repeating: 0.0, count: N/2)
        var tempSplitComplex : DSPDoubleSplitComplex = DSPDoubleSplitComplex(realp: &tempSplitComplexReal, imagp: &tempSplitComplexImag)
        
        // For polar coordinates
        var mag : [Double] = [Double](repeating: 0.0, count: N/2)
        var phase : [Double] = [Double](repeating: 0.0, count: N/2)
        
        // ----------------------------------------------------------------
        // Forward FFT
        // ----------------------------------------------------------------
        
        var valuesAsComplex : UnsafeMutablePointer<DSPDoubleComplex>? = nil
        
        values.withUnsafeMutableBytes {
            valuesAsComplex = $0.baseAddress?.bindMemory(to: DSPDoubleComplex.self, capacity: values1.count)
        }
        
        // Scramble-pack the real data into complex buffer in just the way that's
        // required by the real-to-complex FFT function that follows.
        vDSP_ctozD(valuesAsComplex!, 2, &tempSplitComplex, 1, N2);
        
        // Do real->complex forward FFT
        vDSP_fft_zripD(fftSetup, &tempSplitComplex, 1, LOG_N, FFTDirection(FFT_FORWARD));
        
        // ----------------------------------------------------------------
        // Get the Frequency Spectrum
        // ----------------------------------------------------------------
        
        var fftMagnitudes = [Double](repeating: 0.0, count: N/2)
        vDSP_zvmagsD(&tempSplitComplex, 1, &fftMagnitudes, 1, N2);
        
        // vDSP_zvmagsD returns squares of the FFT magnitudes, so take the root here
        let roots = sqrt(fftMagnitudes)
        
        // Normalize the Amplitudes
        var fullSpectrum = [Double](repeating: 0.0, count: N/2)
        vDSP_vsmulD(roots, vDSP_Stride(1), [1.0 / Double(N)], &fullSpectrum, 1, N2)
        
        // ----------------------------------------------------------------
        // Convert from complex/rectangular (real, imaginary) coordinates
        // to polar (magnitude and phase) coordinates.
        // ----------------------------------------------------------------
        
        vDSP_zvabsD(&tempSplitComplex, 1, &mag, 1, N2);
        
        // Beware: Outputted phase here between -PI and +PI
        // https://developer.apple.com/library/prerelease/ios/documentation/Accelerate/Reference/vDSPRef/index.html#//apple_ref/c/func/vDSP_zvphasD
        vDSP_zvphasD(&tempSplitComplex, 1, &phase, 1, N2);
                
        // ----------------------------------------------------------------
        // Bandpass Filtering
        // ----------------------------------------------------------------
        
        // Get the Frequencies for the current Framerate
        let freqs = getFrequencies(N,fps: framesPerSecond)
        // Get a Bandpass Filter
        let bandPassFilter = generateBandPassFilter(freqs)
        
        // Multiply phase and magnitude with the bandpass filter
        mag = mul(mag, y: bandPassFilter.0)
        phase = mul(phase, y: bandPassFilter.0)
        
        // Output Variables
        let filteredSpectrum = mul(fullSpectrum, y: bandPassFilter.0)
        var filteredPhase = phase
        
        // ----------------------------------------------------------------
        // Determine Maximum Frequency
        // ----------------------------------------------------------------
        //print("========>FFT Out Pub Len:", filteredSpectrum.count)
        if publish {
            audio.fourierTransformOutput = audio.segmentAndAverage(array: filteredSpectrum, segmentLength: 10)
        }
        //print("========>FFT Out Pub Averaged Len:", audio.fourierTransformOutput.count)

        let maxFrequencyResult = maxWithIndex(filteredSpectrum)
        let maxFrequency = freqs[maxFrequencyResult.1]
        let maxPhase = filteredPhase[maxFrequencyResult.1]
        
        print("  FFT Amplitude: \(str(maxFrequencyResult.0))", "Frequency: \(str(maxFrequency))", "Phase: \(str(maxPhase + .pi / 2))")
        
        // ----------------------------------------------------------------
        // Convert from polar coordinates back to rectangular coordinates.
        // ----------------------------------------------------------------
        
        tempSplitComplex = DSPDoubleSplitComplex(realp: &mag, imagp: &phase)

        var complexAsValue : UnsafeMutablePointer<Double>? = nil
        
        tempComplex.withUnsafeMutableBytes {
            complexAsValue = $0.baseAddress?.bindMemory(to: Double.self, capacity: values.count)
        }
        
        vDSP_ztocD(&tempSplitComplex, 1, &tempComplex, 2, N2);
        vDSP_rectD(complexAsValue!, 2, complexAsValue!, 2, N2);
        vDSP_ctozD(&tempComplex, 2, &tempSplitComplex, 1, N2);
        
        // ----------------------------------------------------------------
        // Do Inverse FFT
        // ----------------------------------------------------------------
        return
        
        // Create result
        var result : [Double] = [Double](repeating: 0.0, count: N)
        var resultAsComplex : UnsafeMutablePointer<DSPDoubleComplex>? = nil
        
        result.withUnsafeMutableBytes {
            resultAsComplex = $0.baseAddress?.bindMemory(to: DSPDoubleComplex.self, capacity: values.count)
        }

        // Do complex->real inverse FFT.
        vDSP_fft_zripD(fftSetup, &tempSplitComplex, 1, LOG_N, FFTDirection(FFT_INVERSE));
        
        // This leaves result in packed format. Here we unpack it into a real vector.
        vDSP_ztocD(&tempSplitComplex, 1, resultAsComplex!, 2, N2);
        
        // Neither the forward nor inverse FFT does any scaling. Here we compensate for that.
        var scale : Double = 0.5/Double(N);
        var copyOfResult = result;
        vDSP_vsmulD(&result, 1, &scale, &copyOfResult, 1, vDSP_Length(N));
        result = copyOfResult
        
        // Print Result
        for k in 0 ..< N {
            print("\(k)   \(values[k])     \(result[k])")
        }
    }
    
    // The bandpass frequencies
    let lowerFreq : Double = 3
    //let higherFreq: Double = 5
    let higherFreq: Double = 5 * 1000000

    // Some Math functions on Arrays
    func mul(_ x: [Double], y: [Double]) -> [Double] {
        var results = [Double](repeating: 0.0, count: x.count)
        vDSP_vmulD(x, 1, y, 1, &results, 1, vDSP_Length(x.count))

        return results
    }
    
    func sqrt(_ x: [Double]) -> [Double] {
        var results = [Double](repeating: 0.0, count: x.count)
        vvsqrt(&results, x, [Int32(x.count)])

        return results
    }
    
    func maxWithIndex(_ x: [Double]) -> (Double, Int) {
        var result: Double = 0.0
        var idx : vDSP_Length = vDSP_Length(0)
        vDSP_maxviD(x, 1, &result, &idx, vDSP_Length(x.count))

        return (result, Int(idx))
    }
}
