/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The class that provides a signal that represents a drum loop.
*/

import Accelerate
import Combine
import AVFoundation

class AudioSpectrogram: NSObject, ObservableObject {
    //var ctr1 = 0
    var captureOutputCtr = 0
    var processCtr = 0
    /// An enumeration that specifies the drum loop provider's mode.
    enum Mode: String, CaseIterable, Identifiable {
        case linear
        case mel
        
        var id: Self { self }
    }
    
    //@Published var mode = Mode.linear
    @Published var mode = Mode.mel

    //@Published var gain: Double = 0.025
    @Published var gain: Double = 0.035
    
    @Published var speed: Double = 1000.0
    @Published var zeroReference: Double = 1000
    
    @Published var outputImage = AudioSpectrogram.emptyCGImage
    
    // MARK: Initialization
    
    override init() {
        super.init()
        configureCaptureSession()
        audioOutput.setSampleBufferDelegate(self,queue: captureQueue)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Properties
    
    lazy var melSpectrogram = MelSpectrogram(sampleCount: AudioSpectrogram.sampleCount)
    
    /// The number of samples per frame — the height of the spectrogram.
    static let sampleCount = 1024
    
    /// The number of displayed buffers — the width of the spectrogram.
    static let spectogramWidth = 768
    
    /// Determines the overlap between frames.
    static let hopCount = 512

    let captureSession = AVCaptureSession()
    let audioOutput = AVCaptureAudioDataOutput()
    let captureQueue = DispatchQueue(label: "captureQueue",
                                     qos: .userInitiated,
                                     attributes: [],
                                     autoreleaseFrequency: .workItem)
    let sessionQueue = DispatchQueue(label: "sessionQueue",
                                     attributes: [],
                                     autoreleaseFrequency: .workItem)
    
    let forwardDCT = vDSP.DCT(count: sampleCount,
                              transformType: .II)!
    
    /// The window sequence for reducing spectral leakage.
    let hanningWindow = vDSP.window(ofType: Float.self,
                                    usingSequence: .hanningDenormalized,
                                    count: sampleCount,
                                    isHalfWindow: false)
    
    let dispatchSemaphore = DispatchSemaphore(value: 1)
    
    /// The highest frequency that the app can represent.
    ///
    /// The first call of `AudioSpectrogram.captureOutput(_:didOutput:from:)` calculates
    /// this value.
    var nyquistFrequency: Float?
    
    /// A buffer that contains the raw audio data from AVFoundation.
    var rawAudioData = [Int16]()
    
    /// Raw frequency-domain values.
    var frequencyDomainValues = [Float](repeating: 0,
                                        count: spectogramWidth * sampleCount)
        
    var rgbImageFormat = vImage_CGImageFormat(
        bitsPerComponent: 32,
        bitsPerPixel: 32 * 3,
        colorSpace: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(
            rawValue: kCGBitmapByteOrder32Host.rawValue |
            CGBitmapInfo.floatComponents.rawValue |
            CGImageAlphaInfo.none.rawValue))!
    
    /// RGB vImage buffer that contains a vertical representation of the audio spectrogram.
    
    let redBuffer = vImage.PixelBuffer<vImage.PlanarF>(
            width: AudioSpectrogram.sampleCount,
            height: AudioSpectrogram.spectogramWidth)

    let greenBuffer = vImage.PixelBuffer<vImage.PlanarF>(
            width: AudioSpectrogram.sampleCount,
            height: AudioSpectrogram.spectogramWidth)
    
    let blueBuffer = vImage.PixelBuffer<vImage.PlanarF>(
            width: AudioSpectrogram.sampleCount,
            height: AudioSpectrogram.spectogramWidth)
    
    let rgbImageBuffer = vImage.PixelBuffer<vImage.InterleavedFx3>(
        width: AudioSpectrogram.sampleCount,
        height: AudioSpectrogram.spectogramWidth)


    /// A reusable array that contains the current frame of time-domain audio data as single-precision
    /// values.
    var timeDomainBuffer = [Float](repeating: 0,
                                   count: sampleCount)
    
    /// A resuable array that contains the frequency-domain representation of the current frame of
    /// audio data.
    var frequencyDomainBuffer = [Float](repeating: 0,
                                        count: sampleCount)
    
    // MARK: Instance Methods
        
    func showData(ctx:String, values: [Float]) {
        let sum = values.reduce(0, +)
        let average = sum / Float(values.count)
        let maxVal = values.max()
        let indexOfMax = values.firstIndex(of: maxVal ?? 0)
        
        print("showData ctx:", ctx, "count:", values.count,
              "\tmin:", str(values.min()),
              "\tmax:", str(maxVal),
              "\tavg:", str(average),
              "\tindexOfMax", indexOfMax
        )
        
    }
    /// Process a frame of raw audio data.
    ///
    /// * Convert supplied `Int16` values to single-precision and write the result to `timeDomainBuffer`.
    /// * Apply a Hann window to the audio data in `timeDomainBuffer`.
    /// * Perform a forward discrete cosine transform and write the result to `frequencyDomainBuffer`.
    /// * Convert frequency-domain values in `frequencyDomainBuffer` to decibels and scale by the
    ///     `gain` value.
    /// * Append the values in `frequencyDomainBuffer` to `frequencyDomainValues`.
    func processData(values16: [Int16]?, valuesFloat:[Float]? = nil) {
        if let values16 = values16 {
            vDSP.convertElements(of: values16,
                                 to: &timeDomainBuffer)
        }
        else {
            timeDomainBuffer = Array(valuesFloat!)
        }
        
        vDSP.multiply(timeDomainBuffer,
                      hanningWindow,
                      result: &timeDomainBuffer)
        
        forwardDCT.transform(timeDomainBuffer,
                             result: &frequencyDomainBuffer)
        
        vDSP.absolute(frequencyDomainBuffer,
                      result: &frequencyDomainBuffer)
        
        switch mode {
            case .linear:
                vDSP.convert(amplitude: frequencyDomainBuffer,
                             toDecibels: &frequencyDomainBuffer,
                             zeroReference: Float(zeroReference))
            case .mel:
                melSpectrogram.computeMelSpectrogram(
                    values: &frequencyDomainBuffer)
                
                vDSP.convert(power: frequencyDomainBuffer,
                             toDecibels: &frequencyDomainBuffer,
                             zeroReference: Float(zeroReference))
        }

        vDSP.multiply(Float(gain),
                      frequencyDomainBuffer,
                      result: &frequencyDomainBuffer)
        
        if frequencyDomainValues.count > AudioSpectrogram.sampleCount {
            frequencyDomainValues.removeFirst(AudioSpectrogram.sampleCount)
        }
        
        if false {
            for i in 0..<frequencyDomainValues.count {
                if i > Int(frequencyDomainValues.count / 2)  {
                    frequencyDomainValues[i] = 100.0
                }
            }
        }

        ///frequencyDomainBuffer - A resuable array that contains the frequency-domain representation of the current frame of audio data.
        ///frequencyDomainValues - Raw frequency-domain values.
        frequencyDomainValues.append(contentsOf: frequencyDomainBuffer)
        
        if processCtr % 100 == 0 {
            showData(ctx: "processData \(processCtr)", values: timeDomainBuffer)
            showData(ctx: "  Freq \(processCtr)", values: frequencyDomainValues)
            print()
        }
        processCtr += 1
    }
    
    /// Creates an audio spectrogram `CGImage` from `frequencyDomainValues`.
    func makeAudioSpectrogramImage() -> CGImage {
        frequencyDomainValues.withUnsafeMutableBufferPointer {
            
            let planarImageBuffer = vImage.PixelBuffer(
                data: $0.baseAddress!,
                width: AudioSpectrogram.sampleCount,
                height: AudioSpectrogram.spectogramWidth,
                byteCountPerRow: AudioSpectrogram.sampleCount * MemoryLayout<Float>.stride,
                pixelFormat: vImage.PlanarF.self)
            
            AudioSpectrogram.multidimensionalLookupTable.apply(
                sources: [planarImageBuffer],
                destinations: [redBuffer, greenBuffer, blueBuffer],
                interpolation: .half)
            
            rgbImageBuffer.interleave(
                planarSourceBuffers: [redBuffer, greenBuffer, blueBuffer])
        }
        
        return rgbImageBuffer.makeCGImage(cgImageFormat: rgbImageFormat) ?? AudioSpectrogram.emptyCGImage
    }
}

import Cocoa

// MARK: Utility functions
extension AudioSpectrogram {
    
    /// Returns the RGB values from a blue -> red -> green color map for a specified value.
    ///
    /// Values near zero return dark blue, `0.5` returns red, and `1.0` returns full-brightness green.
    static var multidimensionalLookupTable: vImage.MultidimensionalLookupTable = {
        let entriesPerChannel = UInt8(32)
        let srcChannelCount = 1
        let destChannelCount = 3
        
        let lookupTableElementCount = Int(pow(Float(entriesPerChannel),
                                              Float(srcChannelCount))) *
        Int(destChannelCount)
        
        let tableData = [UInt16](unsafeUninitializedCapacity: lookupTableElementCount) {
            buffer, count in
            
            /// Supply the samples in the range `0...65535`. The transform function
            /// interpolates these to the range `0...1`.
            let multiplier = CGFloat(UInt16.max)
            var bufferIndex = 0
            
            for gray in ( 0 ..< entriesPerChannel) {
                /// Create normalized red, green, and blue values in the range `0...1`.
                let normalizedValue = CGFloat(gray) / CGFloat(entriesPerChannel - 1)
              
                // Define `hue` that's blue at `0.0` to red at `1.0`.
                let hue = 0.6666 - (0.6666 * normalizedValue)
                let brightness = sqrt(normalizedValue)
                
                let color = NSColor(hue: hue,
                                    saturation: 1,
                                    brightness: brightness,
                                    alpha: 1)
                
                var red = CGFloat()
                var green = CGFloat()
                var blue = CGFloat()
                
                color.getRed(&red,
                             green: &green,
                             blue: &blue,
                             alpha: nil)
     
                buffer[ bufferIndex ] = UInt16(green * multiplier)
                bufferIndex += 1
                buffer[ bufferIndex ] = UInt16(red * multiplier)
                bufferIndex += 1
                buffer[ bufferIndex ] = UInt16(blue * multiplier)
                bufferIndex += 1
            }
            
            count = lookupTableElementCount
        }
        
        let entryCountPerSourceChannel = [UInt8](repeating: entriesPerChannel,
                                                 count: srcChannelCount)
        
        return vImage.MultidimensionalLookupTable(entryCountPerSourceChannel: entryCountPerSourceChannel,
                                                  destinationChannelCount: destChannelCount,
                                                  data: tableData)
    }()
    
    /// A 1x1 Core Graphics image.
    static var emptyCGImage: CGImage = {
        let buffer = vImage.PixelBuffer(
            pixelValues: [0],
            size: .init(width: 1, height: 1),
            pixelFormat: vImage.Planar8.self)
        
        let fmt = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 8 ,
            colorSpace: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            renderingIntent: .defaultIntent)
        
        return buffer.makeCGImage(cgImageFormat: fmt!)!
    }()
    
    func readFile() {
        let name = "Example 1_SkyPad"

        //numberFormatter.numberStyle = .decimal
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            print("File  not found in the app bundle.")
            return
        }
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let durationSeconds = Double(audioFile.length) / audioFile.fileFormat.sampleRate
            let frames = AVAudioFrameCount(audioFile.length)
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                                  frameCapacity: AVAudioFrameCount(audioFile.length))
            guard buffer != nil else {
                return
            }
            try audioFile.read(into: buffer!)

            let channelIndex = 0 // Specify the index of the desired channel
            let segmentLength = 1024
            
            let floatChannelData = buffer?.floatChannelData!
            let channelData = floatChannelData![channelIndex]
            
            let totalSampleCount = buffer!.frameLength
            let segmentCount = Int(totalSampleCount) / segmentLength
            
            var segments: [[Float]] = []
            
            for segmentIndex in 0..<segmentCount {
                //TODO shoudl overlap segments into processing
                let startSample = segmentIndex * segmentLength
                let endSample = startSample + segmentLength
                
                var segment: [Float] = []
                
                for sampleIndex in startSample..<endSample {
                    let sample = channelData[Int(sampleIndex)]
                    segment.append(sample)
                }
                segments.append(segment)
            }
            print("readFile", name,
                  "\n  duration secs:", str(durationSeconds),
                  "\n  segments:", segments.count)
            
            let numSegments = segments.count
            var segmentIndex = 0
            
            let timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
                let segment = segments[segmentIndex]
                /// TODO overlap segments
                let multipliedArray = segment.map { $0 * 1000.0 }
                for _ in 0..<2 {
                    self.processData(values16: nil, valuesFloat: multipliedArray)
                }
                DispatchQueue.main.async { [self] in
                    outputImage = makeAudioSpectrogramImage()
                }
                if segmentIndex >= numSegments-1 {
                    timer.invalidate()
                }
                segmentIndex += 1
            }

            // Start the timer
            RunLoop.current.add(timer, forMode: .common)

            print("==========DONE==========")
        }
        catch {
            print("Error loading file: \(error.localizedDescription)")
        }
    }
    
    func str(_ inVal:Float?) -> String {
        if inVal == nil {
            return "nil"
        }
        return String(format: "%.2f", inVal!)
    }
    func str(_ inVal:Double?) -> String {
        if inVal == nil {
            return "nil"
        }

        return String(format: "%.2f", inVal!)
    }

// FFT ========================

    func findDominantFrequencies(melSpectrogram: [Float], sampleRate: Float, numFrequencyBins: Int) -> [Float] {
        let magnitudeSpectrum = melSpectrogram.map { $0.magnitude }
        let smoothedSpectrum = smoothSpectrum(magnitudeSpectrum)
        let peakIndices = findPeakIndices(smoothedSpectrum)
        let sortedPeaks = sortPeaks(peakIndices: peakIndices, spectrum: smoothedSpectrum)
        let dominantFrequencies = extractDominantFrequencies(sortedPeaks: sortedPeaks, sampleRate: sampleRate, numFrequencyBins: numFrequencyBins)
        return dominantFrequencies
    }

    func smoothSpectrum(_ spectrum: [Float]) -> [Float] {
        // Smoothing implementation...
        // You can use techniques like moving average, Gaussian smoothing, or median filtering.
        let windowSize = 3 // Adjust the window size as needed
        var smoothedSpectrum = [Float](repeating: 0.0, count: spectrum.count)
        
        for i in 0..<spectrum.count {
            var sum: Float = 0.0
            var count: Float = 0.0
            
            let startIndex = max(0, i - windowSize/2)
            let endIndex = min(spectrum.count - 1, i + windowSize/2)
            
            for j in startIndex...endIndex {
                sum += spectrum[j]
                count += 1.0
            }
            smoothedSpectrum[i] = sum / count
        }
        return smoothedSpectrum
    }

    func findPeakIndices(_ spectrum: [Float]) -> [Int] {
        var peakIndices: [Int] = []
        for i in 1..<(spectrum.count - 1) {
            if spectrum[i] > spectrum[i - 1] && spectrum[i] > spectrum[i + 1] {
                peakIndices.append(i)
            }
        }
        return peakIndices
    }

    func sortPeaks(peakIndices: [Int], spectrum: [Float]) -> [(index: Int, magnitude: Float)] {
        let peaks = peakIndices.map { (index: $0, magnitude: spectrum[$0]) }
        let sortedPeaks = peaks.sorted { $0.magnitude > $1.magnitude }
        return sortedPeaks
    }

    func extractDominantFrequencies(sortedPeaks: [(index: Int, magnitude: Float)], sampleRate: Float, numFrequencyBins: Int) -> [Float] {
        let dominantPeaks = sortedPeaks.prefix(4) // Extract the top 4 peaks
        let dominantFrequencies = dominantPeaks.map { indexToFrequency(index: $0.index, sampleRate: sampleRate, numFrequencyBins: numFrequencyBins) }
        return dominantFrequencies
    }

    func indexToFrequency(index: Int, sampleRate: Float, numFrequencyBins: Int) -> Float {
        let nyquistFrequency = sampleRate / 2
        let binWidth = nyquistFrequency / Float(numFrequencyBins)
        let frequency = Float(index) * binWidth
        return frequency
    }

}
