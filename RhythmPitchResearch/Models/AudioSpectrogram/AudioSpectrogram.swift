/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The class that provides a signal that represents a drum loop.
*/

import Accelerate
import Combine
import AVFoundation

class AudioSpectrogram: NSObject, ObservableObject {
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
    @Published var samplesPerFrame = 1024.0

    @Published var outputImage = AudioSpectrogram.emptyCGImage

    var numberFormatter = NumberFormatter()

    // MARK: Initialization
    
    override init() {
        super.init()
        numberFormatter.numberStyle = .decimal
        configureCaptureSession()
        audioOutput.setSampleBufferDelegate(self,queue: captureQueue)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Properties
    
    lazy var melSpectrogram = MelSpectrogram(sampleCount: Int(samplesPerFrame))
    
    var sampleRate:Double = 0.0
    
    /// The number of samples per frame — the height of the spectrogram.
    
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
    
    let forwardDCT = vDSP.DCT(count: Int(samplesPerFrame),
                              transformType: .II)!
    
    /// The window sequence for reducing spectral leakage.
    let hanningWindow = vDSP.window(ofType: Float.self,
                                    usingSequence: .hanningDenormalized,
                                    count: Int(samplesPerFrame),
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
    var frequencyDomainValuesForImage = [Float](repeating: 0,
                                        count: spectogramWidth * samplesPerFrame)
        
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
            width: AudioSpectrogram.samplesPerFrame,
            height: AudioSpectrogram.spectogramWidth)

    let greenBuffer = vImage.PixelBuffer<vImage.PlanarF>(
            width: AudioSpectrogram.samplesPerFrame,
            height: AudioSpectrogram.spectogramWidth)
    
    let blueBuffer = vImage.PixelBuffer<vImage.PlanarF>(
            width: AudioSpectrogram.samplesPerFrame,
            height: AudioSpectrogram.spectogramWidth)
    
    let rgbImageBuffer = vImage.PixelBuffer<vImage.InterleavedFx3>(
        width: AudioSpectrogram.samplesPerFrame,
        height: AudioSpectrogram.spectogramWidth)


    /// A reusable array that contains the current frame of time-domain audio data as single-precision
    /// values.
    var timeDomainBuffer = [Float](repeating: 0,
                                   count: samplesPerFrame)
    
    /// A resuable array that contains the frequency-domain representation of the current frame of
    /// audio data.
    var frequencyDomainValues = [Float](repeating: 0, count: samplesPerFrame)
    
    // MARK: Instance Methods
        
    func showData(ctx:String, idx: Int, values: [Float]) {
        let sum = values.reduce(0, +)
        let average = sum / Float(values.count)
        let maxVal = values.max()
        let indexOfMax = values.firstIndex(of: maxVal ?? 0)
        
        print("Idx:\(idx) Data-Ctx:\(ctx) \tCount:\(str(values.count)) \tMax:\(str(maxVal))", terminator: "")
//              "\tmin:", str(values.min()),
//              "\tmax:", str(maxVal),
//              "\tavg:", str(average),
//              "\tindexOfMax", indexOfMax
//        )
        
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
        
        ///A class that provides single-precision discrete cosine transform.
        ///The output of the DCT is a set of numbers. Each number in the output represents the weight, or amplitude, of a certain frequency in the input data.
        
        //var frequencyDomainValuesTemp = [Float](repeating: 0, count: AudioSpectrogram.samplesPerFrame)

        forwardDCT.transform(timeDomainBuffer,
                             result: &frequencyDomainValues
                             //result: &frequencyDomainValuesTemp
        )
        
//        //filter out other frequencies
//        let lowFrequency = 200.0
//        let highFrequency = 800.0
//        let lowIndex = Int(lowFrequency * Double(frequencyDomainValues.count) / sampleRate)
//        let highIndex = Int(highFrequency * Double(frequencyDomainValues.count) / sampleRate)
//        frequencyDomainValues = [Float](repeating: 0, count: highIndex - lowIndex)
//        //frequencyDomainValues = frequencyDomainValuesTemp[lowIndex...highIndex]
//        var j = 0
//        for i in lowIndex..<highIndex {
//            frequencyDomainValues[j] = frequencyDomainValuesTemp[i]
//            j += 1
//        }
        
        //print(timeDomainBuffer.count, frequencyDomainBuffer.count)
        
        /// Populates `result` with the absolute values of `vector`,
        vDSP.absolute(frequencyDomainValues, result: &frequencyDomainValues)
        
        switch mode {
            case .linear:
                /// Converts power to decibels, single-precision.
                vDSP.convert(amplitude: frequencyDomainValues,
                             toDecibels: &frequencyDomainValues,
                             zeroReference: Float(zeroReference))
            case .mel:
                melSpectrogram.computeMelSpectrogram(values: &frequencyDomainValues)

                /// Converts power to decibels, single-precision.
                vDSP.convert(power: frequencyDomainValues,
                             toDecibels: &frequencyDomainValues,
                             zeroReference: Float(zeroReference))
        }

        vDSP.multiply(Float(gain),
                      frequencyDomainValues,
                      result: &frequencyDomainValues)
        
        if frequencyDomainValuesForImage.count > AudioSpectrogram.samplesPerFrame {
            frequencyDomainValuesForImage.removeFirst(AudioSpectrogram.samplesPerFrame)
        }
        
        ///frequencyDomainBuffer - A resuable array that contains the frequency-domain representation of the current frame of audio data.
        ///frequencyDomainValues - Raw frequency-domain values.
        frequencyDomainValuesForImage.append(contentsOf: frequencyDomainValues)
        
        var firstAboveZeroIndex:Int?
        for i in stride(from: frequencyDomainValues.count - 1, through: 0, by: -1) {
            if frequencyDomainValues[i] > 0 {
                firstAboveZeroIndex = i
                break
            }
        }
        var topAvg:Double? = nil
        if let firstAboveZeroIndex = firstAboveZeroIndex {
            let sliceSize = Int(Double(frequencyDomainValues.count) * 0.1 * 0.2)
            var total = 0.0
            for i in 0..<sliceSize {
                total += Double(frequencyDomainValues[firstAboveZeroIndex - i])
            }
            topAvg = total / Double(sliceSize)
        }

        showData(ctx: "Time", idx: processCtr, values: timeDomainBuffer)
        print("\t", terminator: " ")
        //showData(ctx: "Freq", idx: processCtr, values: frequencyDomainValues)
        //if let topAvg = topAvg {
            //print("\tFirstAbove:", firstAboveZeroIndex ?? "",terminator: "")
            print("\tFirstAboveAvg:", str(topAvg), terminator: "")
        //}
        print()
//        if processCtr == 230 {
//            print("\n")
//            for f in 0..<frequencyDomainValues.count {
//                print(str(frequencyDomainValues[f]))
//            }
//            print("\n")
//        }
        processCtr += 1
    }
    
    func findPeaks(in buffer: [Float]) -> [Int] {
        var peaks = [Int]()
        for i in 1..<buffer.count-1 {
            if buffer[i] > buffer[i-1] && buffer[i] > buffer[i+1] {
///                Converting to decibels involves taking the logarithm of the amplitude or power. If the amplitude or power is less than 1, its logarithm will be negative.
///                In the context of audio signal processing, a value in decibels is negative if it is less than the reference value. The reference value is typically the maximum possible
///                amplitude or power. Therefore, a negative decibel value simply means that the corresponding frequency component has less amplitude or power than the reference.
                if buffer[i] > 0 {
                    peaks.append(i)
                }
            }
        }
        return peaks
    }
    
    /// Creates an audio spectrogram `CGImage` from `frequencyDomainValues`.
    func makeAudioSpectrogramImage() -> CGImage {
        frequencyDomainValuesForImage.withUnsafeMutableBufferPointer {
            
            let planarImageBuffer = vImage.PixelBuffer(
                data: $0.baseAddress!,
                width: AudioSpectrogram.samplesPerFrame,
                height: AudioSpectrogram.spectogramWidth,
                byteCountPerRow: AudioSpectrogram.samplesPerFrame * MemoryLayout<Float>.stride,
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
    
    func analyzeFile() {
        //let name = "Example 2_SkyPad"
        let name = "C_Octave_To_C_Piano_And_Down" //C_Octave_To_C_Piano"

        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            print("File  not found in the app bundle.")
            return
        }
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let durationSeconds = Double(audioFile.length) / audioFile.fileFormat.sampleRate
            sampleRate = audioFile.fileFormat.sampleRate
            let totalSamples = AVAudioFrameCount(audioFile.length)
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                          frameCapacity: AVAudioFrameCount(audioFile.length))
            guard buffer != nil else {
                return
            }
            try audioFile.read(into: buffer!)

            let channelIndex = 0 /// Specify the index of the desired channel
            //let frameLength = 1024 ///A short slice of a time series used for analysis purposes. This usually corresponds to a single column of a spectrogram matrix.
            //let frameLength = 2048///A short slice of a time series used for analysis purposes. This usually corresponds to a single column of a spectrogram matrix.

            let floatChannelData = buffer?.floatChannelData!
            let channelData = floatChannelData![channelIndex]
            
            let totalSampleCount = buffer!.frameLength
            let frameCount = Int(totalSampleCount) / AudioSpectrogram.samplesPerFrame
            let frameDuration = durationSeconds / Double(frameCount)
            
            var frames: [[Float]] = []
            
            for segmentIndex in 0..<frameCount {
                //TODO shoudl overlap segments into processing
                let startSample = segmentIndex * AudioSpectrogram.samplesPerFrame
                let endSample = startSample + AudioSpectrogram.samplesPerFrame
                var frame: [Float] = []
                for sampleIndex in startSample..<endSample {
                    let sample = channelData[Int(sampleIndex)]
                    frame.append(sample)
                }
                frames.append(frame)
            }

            print("\nTotalSamples:\(str(Int(totalSamples))), Duration:\(str(durationSeconds)) seconds, SamplingRate:\(audioFile.fileFormat.sampleRate)")
            print("  FrameLength:\(AudioSpectrogram.samplesPerFrame) TotalFrames:\(str(Int(frames.count))), FrameDuration:\(str(frameDuration))")

            let numSegments = frames.count
            var segmentIndex = 0
            
            if true {
                let timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
                    let frame = frames[segmentIndex]
                    /// TODO overlap segments
                    let multipliedArray = frame.map { $0 * 1000.0 }
                    //for _ in 0..<2 { WHY ????
                        self.processData(values16: nil, valuesFloat: multipliedArray)
                    //}
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
            }
            else {
                for frameIndex in 0..<frames.count {
                    let frame = frames[frameIndex]
                    let multipliedArray = frame.map { $0 * 1000.0 }
                    for _ in 0..<2 {
                        self.processData(values16: nil, valuesFloat: multipliedArray)
                    }

                }
            }

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
    
    func str(_ inVal:Int) -> String {
        numberFormatter.string(from: NSNumber(value: inVal)) ?? ""
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
