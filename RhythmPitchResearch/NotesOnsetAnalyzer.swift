import Accelerate
import Combine
import AVFoundation

class NoteOnset : CustomStringConvertible {
    var onsetFrame:Int
    var frameCount:Int?
    var value:Double = 0.0
    var increaseThatTriggeredOnset:Float
    var dataValue:Float
    
    init (onsetFrame:Int, dataValue:Float, increaseThatTriggeredOnset:Float, frameCount:Int? = nil) {
        self.onsetFrame = onsetFrame
        self.increaseThatTriggeredOnset = increaseThatTriggeredOnset
        self.frameCount = frameCount
        self.dataValue = dataValue
    }
    
    var description: String {
        let data = String(format: "%.4f", self.dataValue)
        let incr = String(format: "%.4f", self.increaseThatTriggeredOnset)
        var s = "Note Offset:\(self.onsetFrame) \tDataVal:\(data) \tIncr%:\(incr)"
        
        if let frameCount = frameCount {
            let value = String(format: "%.2f", self.value)
            s += "\tFrames:\(frameCount) \tValue:\(value)"
        }
        return s
    }
}

class NoteOnsetAnalyser {
    let samplesPerFrame = 1024
    
    func getAvg(_ data:[Float]) -> Float {
        return 1 * data.reduce(0, +) / Float(data.count)
    }
    
    func processFrequencies(timeFrameValues:[Float]) -> [Float] {
        
        var timeDomainBuffer = Array(timeFrameValues)
        var hanningWindow:[Float]
        hanningWindow = vDSP.window(ofType: Float.self,
                                    usingSequence: .hanningDenormalized,
                                    count: Int(samplesPerFrame),
                                    isHalfWindow: false)
        var forwardDCT:vDSP.DCT
        forwardDCT = vDSP.DCT(count: Int(samplesPerFrame), transformType: .II)!
        
        vDSP.multiply(timeDomainBuffer,
                      hanningWindow,
                      result: &timeDomainBuffer)
        
        var frequencyDomainValues:[Float]
        frequencyDomainValues = [Float](repeating: 0, count: Int(samplesPerFrame))
        
        ///A class that provides single-precision discrete cosine transform.
        ///The output of the DCT is a set of numbers. Each number in the output represents the weight, or amplitude, of a certain frequency in the input data.
        
        forwardDCT.transform(timeDomainBuffer,
                             result: &frequencyDomainValues
                             //result: &frequencyDomainValuesTemp
        )
        
        /// Populates `result` with the absolute values of `vector`,
        vDSP.absolute(frequencyDomainValues, result: &frequencyDomainValues)
        
        var melSpectrogram = MelSpectrogram(sampleCount: Int(samplesPerFrame))
        var zeroReference: Double = 1000
        
        if false {
            /// Converts power to decibels, single-precision.
            vDSP.convert(amplitude: frequencyDomainValues,
                         toDecibels: &frequencyDomainValues,
                         zeroReference: Float(zeroReference))
        }
        else {
            melSpectrogram.computeMelSpectrogram(values: &frequencyDomainValues)
            
            /// Converts power to decibels, single-precision.
            vDSP.convert(power: frequencyDomainValues,
                         toDecibels: &frequencyDomainValues,
                         zeroReference: Float(zeroReference))
        }
        
        let gain: Double = 0.035
        vDSP.multiply(Float(gain),
                      frequencyDomainValues,
                      result: &frequencyDomainValues)
        
        return frequencyDomainValues
    }
    
    ///Loook for onsets across all frames
    func calcNoteOnsetsFullScan(ctx:String, increaseCutoff:Float, maxCutoff:Float, frames:[[Float]]) -> [NoteOnset] {
        var offsets:[NoteOnset] = []
        let sliceLen = 8
        let cutoff:Float = 1.35 //increaseCutoff
        var frameIndex = sliceLen+1
        var firstValue:Int?
        
        while frameIndex < frames.count - sliceLen-1 {
            let frame = frames[frameIndex]
            let frameAvg = getAvg(frame)
            
            print("\(frameIndex),   \(str(frameAvg * 10,dec:4))")
            
            var prev:[Float] = []
            var next:[Float] = []
            for i in 1..<sliceLen + 1 {
                //                prev.append(frame[frameCount-i])
                //                next.append(frame[frameCount+i])
                prev.append(getAvg(frames[frameIndex-i]))
                next.append(getAvg(frames[frameIndex+i]))
            }
            let prevAvg = getAvg(prev)
            let nextAvg = getAvg(next)
            
            // compare to prev avg
            let increaseFromPrev = frameAvg / prevAvg
            //let increaseToNext = frameAvg / nextAvg
            
            if frameIndex == 410 {
                frameIndex = frameIndex + 0
            }
            
            if frameAvg > 0.02 {
                if increaseFromPrev > cutoff {
                    if frameAvg > getAvg(frames[frameIndex-1]) && frameAvg > getAvg(frames[frameIndex+1]) {
                        let frameCnt:Int? = offsets.count==0 ? nil : frameIndex - offsets[offsets.count - 1].onsetFrame
                        if firstValue == nil {
                            firstValue = frameCnt
                        }
                        //print("Onset", rowIndex, "Value", value ?? "")
                        if offsets.count > 0 {
                            offsets[offsets.count - 1].frameCount = frameCnt
                            offsets[offsets.count - 1].value = Double(frameCnt!) / Double(firstValue!)
                        }
                        let onset = NoteOnset(onsetFrame: frameIndex, dataValue: frameAvg, increaseThatTriggeredOnset: increaseFromPrev)
                        offsets.append(onset)
                        frameIndex += sliceLen
                        
                    }
                }
            }
            
            frameIndex += 1
        }
        
        //============= frequences
        
        //each column is the 1024 frequency output for that note
        var frequencies:[[Float]] = []
        for _ in 0..<self.samplesPerFrame {
            frequencies.append([])
        }

        for noteIndex in 0..<offsets.count {
            let note = offsets[noteIndex]
            print(noteIndex, note)
            var freqs = processFrequencies(timeFrameValues: frames[note.onsetFrame])
            for i in 0..<freqs.count {
                frequencies[i].append(freqs[i])
            }
        }

    
        if false {
            for f in 0..<self.samplesPerFrame {
                print("\(f) ", terminator: "")
                for note in 0..<offsets.count {
                    if [0, 4, 7, 14].contains(note) {
                        print(" , \(str(frequencies[f][note], dec: 4))", terminator: "")
                    }
                }
                print()
            }
        }

        return offsets
    }
    
    // =====================================================
    
    func getNoteOnsetFrom(frames:[[Float]], startIndex:Int, thresholdIncrease:Float ) -> NoteOnset? {
        
        let sliceLen = 8
        var frameIndex = startIndex
        
        while frameIndex < frames.count - sliceLen-1 {
            let frame = frames[frameIndex]
            let frameAvg = getAvg(frame)
            
            //print("\(frameIndex),   \(str(frameAvg * 10,dec:4))")
            
            var prev:[Float] = []
            var next:[Float] = []
            for i in 1..<sliceLen + 1 {
                //                prev.append(frame[frameCount-i])
                //                next.append(frame[frameCount+i])
                prev.append(getAvg(frames[frameIndex-i]))
                next.append(getAvg(frames[frameIndex+i]))
            }
            let prevAvg = getAvg(prev)
            let nextAvg = getAvg(next)
            
            // compare to prev avg
            let increaseFromPrev = frameAvg / prevAvg
            //let increaseToNext = frameAvg / nextAvg
            
            if frameIndex == 410 {
                frameIndex = frameIndex + 0
            }
            
            if frameAvg > 0.02 {
                if increaseFromPrev > thresholdIncrease {
                    if frameAvg > getAvg(frames[frameIndex-1]) && frameAvg > getAvg(frames[frameIndex+1]) {
                        let onset = NoteOnset(onsetFrame: frameIndex, dataValue: frameAvg, increaseThatTriggeredOnset: increaseFromPrev)
                        return onset
                    }
                }
            }
            frameIndex += 1
        }
        return nil
    }
    
    func calcNoteOnsets(frames:[[Float]]) -> [NoteOnset] {
        let givenValues = [2, 2, 1, 1, 2, 0.5, 0.5, 2, 1, 4]
        //var givenIndex = 0
        
        var noteOnsets:[NoteOnset] = []
        var framesIndex = 10
        let initialThresholdIncrease:Float = 1.5
        var currentThresholdIncrease = initialThresholdIncrease
        
        var framesPerUnitValue:Int?
        var nextPredictedIndex:Int?
        
        while true {
            var noteOnset = getNoteOnsetFrom(frames: frames,
                                             startIndex: framesIndex,
                                             thresholdIncrease: currentThresholdIncrease)
            guard let noteOnset = noteOnset else {
                print("No next note")
                break
            }
            print(noteOnset)

            if noteOnsets.count > 0 {
                print("gotIndex:", noteOnset.onsetFrame, "predicted:", nextPredictedIndex ?? "", "threshold",
                      str(currentThresholdIncrease))

                if nextPredictedIndex != nil {
                    let discrep = noteOnset.onsetFrame - nextPredictedIndex!
                    let allowed = Int(Double(framesPerUnitValue!) * givenValues[noteOnsets.count-1] * 0.5)
                    if discrep > allowed {
                        currentThresholdIncrease *= 0.9
                        continue
                    }
                }
                
                noteOnsets.append(noteOnset)
                let framesDiff:Int = noteOnsets[1].onsetFrame - noteOnsets[0].onsetFrame
                noteOnsets[noteOnsets.count - 1].frameCount = framesDiff
                if noteOnsets.count == 2 {
                    framesPerUnitValue = Int(Double(framesDiff) / givenValues[0])
                }
                nextPredictedIndex = noteOnset.onsetFrame + Int((givenValues[noteOnsets.count-1] * Double(framesPerUnitValue!)))
                currentThresholdIncrease = initialThresholdIncrease
                //givenIndex += 1
                print(" Stored -->", noteOnset)
                if noteOnset.onsetFrame == 371 {
                    print("+++++++++++++")
                }
            }
            else {
                noteOnsets.append(noteOnset)
            }
            print()

            framesIndex = noteOnset.onsetFrame + 8
        }
        return noteOnsets
    }

    func analyzeFile() {
        let name = "iPhone_Ex27_Piano"//SineUp_PianoDown_Octave" //Quarter1Eigth2_Octave"
        let ext = "m4a"
        let noteAnalyzer = NoteOnsetAnalyser()
        //let name = "C_Octave_To_C_Piano_And_Down" //C_Octave_To_C_Piano"

        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("Error :: File  not found in the app bundle.")
            return
        }
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let durationSeconds = Double(audioFile.length) / audioFile.fileFormat.sampleRate
            let sampleRate = audioFile.fileFormat.sampleRate
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
            let frameCount = Int(totalSampleCount) / Int(self.samplesPerFrame)
            let frameDuration = durationSeconds / Double(frameCount)
            
            var amplitudeFrames: [[Float]] = []
            
            for segmentIndex in 0..<frameCount {
                //TODO shoudl overlap segments into processing
                let startSample = segmentIndex * Int(self.samplesPerFrame)
                let endSample = startSample + Int(self.samplesPerFrame)
                var frame: [Float] = []
                for sampleIndex in startSample..<endSample {
                    //let sample = channelData[Int(sampleIndex)] //   TODO - is absolute OK????????
                    let sample = abs(channelData[Int(sampleIndex)])
                    frame.append(sample)
                }
                amplitudeFrames.append(frame)
            }
            
            //noteAnalyzer.calcNoteOnsets(ctx: "Amplitudes", increaseCutoff: 2.0, maxCutoff: 0.0, frames: amplitudeFrames)
            noteAnalyzer.calcNoteOnsets(frames: amplitudeFrames)

            print("\nTotalSamples:\(totalSamples), Duration:\(str(durationSeconds)) seconds, SamplingRate:\(audioFile.fileFormat.sampleRate)")
            print("  FrameLength:\(samplesPerFrame) TotalFrames:\(amplitudeFrames.count), FrameDuration:\(str(frameDuration))")

            let numSegments = amplitudeFrames.count
            var segmentIndex = 0
            
            var frequencies:[[Float]] = []
        }
        catch {
            print("Error loading file: \(error.localizedDescription)")
        }
    }
    
    func str(_ inVal:Float?, dec:Int=2) -> String {
        if inVal == nil {
            return "nil"
        }
        return String(format: "%.\(dec)f", inVal!)
    }
    
    func str(_ inVal:Double?) -> String {
        if inVal == nil {
            return "nil"
        }

        return String(format: "%.2f", inVal!)
    }
    

}