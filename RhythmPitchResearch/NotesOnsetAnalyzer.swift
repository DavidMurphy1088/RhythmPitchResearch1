import AudioKit
import AudioToolbox
import SoundpipeAudioKit
import SwiftUI
import AVFoundation

class NoteOnset : CustomStringConvertible {
    var onsetFrame:Int
    var onsetSeconds:Float = 0
    var frameCount:Int?
    var value:Float = 0.0
    var durationSeconds:Float = 0
    var amplitudeIncreaseThatTriggeredOnset:Float
    var dataValue:Float
    var frequency:Float?
    var frequencyMagnitude:Float?
    var noteName = ""
    
    init (onsetFrame:Int, dataValue:Float, amplitudeIncreaseThatTriggeredOnset:Float, frameCount:Int? = nil) {
        self.onsetFrame = onsetFrame
        self.amplitudeIncreaseThatTriggeredOnset = amplitudeIncreaseThatTriggeredOnset
        self.frameCount = frameCount
        self.dataValue = dataValue
    }
    
    var description: String {
        let data = String(format: "%.4f", self.dataValue)
        let incr = String(format: "%.4f", self.amplitudeIncreaseThatTriggeredOnset)
        var s = "Note Frame:\(self.onsetFrame) Time:\(String(format: "%.2f", self.onsetSeconds)) \tDataVal:\(data) \tIncr%:\(incr)"
        
        if let frameCount = frameCount {
            let value = String(format: "%.2f", self.value)
            let seconds = String(format: "%.2f", self.durationSeconds)
            s += "\tFrames:\(frameCount) \tSeconds:\(seconds) \tValue:\(value) "
        }
        if let frequency = self.frequency {
            s += "\tFreqMag:\(String(format: "%.2f", frequencyMagnitude!))"
            s += "\tFreq:\(String(format: "%.2f", frequency))"
            s += "\tName:\(self.noteName))"
        }
        return s
    }
}

class FrequencyReading {
    var time:Float
    var magnitude:Float
    var frequency:Float
    init(time:Float, magnitude:Float, frequency:Float) {
        self.time = time
        self.magnitude = magnitude
        self.frequency = frequency
    }
}

class NoteOnsetAnalyser {
    let samplesPerFrame = 1024
    var player:AudioPlayer?
    var lastPitch:Float = 0
    var handlerCallNum = 0
    var startTimeMs:Int64 = 0
    var pitchTap:PitchTap!
    let engine = AudioEngine()
    var frequencyReadings:[FrequencyReading] = []
    
    func getAbsoluteAvg(_ data:[Float]) -> Float {
        let aData = data.map { abs($0) }
        return 1 * aData.reduce(0, +) / Float(data.count)
    }
    
    func getUrl() -> URL? {
        let name = "Sequencer_C_To_G" //iPhone_Ex1_Piano" //iPhone_Three_Octaves"
        let ext = "wav"
        let noteAnalyzer = NoteOnsetAnalyser()
        //let name = "C_Octave_To_C_Piano_And_Down" //C_Octave_To_C_Piano"
        
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("Error :: File  not found in the app bundle.")
            return nil
        }
        return url
    }

    func getNoteOnsetFrom(frames:[[Float]], startIndex:Int, thresholdIncrease:Float ) -> NoteOnset? {
        
        let sliceLen = 8
        var frameIndex = startIndex
        //var distanceFromMiddle = 1
        var ctr = 0
        //var indexHitEdge = false
        
        while frameIndex < frames.count - sliceLen-1 {
            let frame = frames[frameIndex]
            let frameAvg = getAbsoluteAvg(frame)
            
            //print("\(frameIndex),   \(str(frameAvg * 10,dec:4))")
            
            var prev:[Float] = []
            var next:[Float] = []
            for i in 1..<sliceLen + 1 {
                //                prev.append(frame[frameCount-i])
                //                next.append(frame[frameCount+i])
                prev.append(getAbsoluteAvg(frames[frameIndex-i]))
                next.append(getAbsoluteAvg(frames[frameIndex+i]))
            }
            let prevAvg = getAbsoluteAvg(prev)
            //let nextAvg = getAvg(next)
            
            // compare to prev avg
            let increaseFromPrev = frameAvg / prevAvg
            //let increaseToNext = frameAvg / nextAvg
            
            if frameIndex == 410 {
                frameIndex = frameIndex + 0
            }
            
            if frameAvg > 0.02 { //0.02 TODO what value
                if increaseFromPrev > thresholdIncrease {
                    if frameAvg > getAbsoluteAvg(frames[frameIndex-1]) && frameAvg > getAbsoluteAvg(frames[frameIndex+1]) {
                        let onset = NoteOnset(onsetFrame: frameIndex, dataValue: frameAvg, amplitudeIncreaseThatTriggeredOnset: increaseFromPrev)
                        return onset
                    }
                }
            }
            frameIndex += 1
            //fan the index out from the middle in alternating directions
//            if frameIndex <= sliceLen + 1 {
//                indexHitEdge = true
//            }
//            if ctr % 2 == 0 || indexHitEdge {
//                frameIndex = midPointIndex + distanceFromMiddle
//                if indexHitEdge {
//                    distanceFromMiddle += 1
//                }
//            }
//            else {
//                frameIndex = midPointIndex - distanceFromMiddle
//                distanceFromMiddle += 1
//            }
            ctr += 1
        }
        return nil
    }
    //=============================================================
    
    func showArray(_ ctx: String, _ array:[Float]) {
        print("\n=========\(ctx)==========")
        for i in 0..<array.count {
            print(i, " , ", str(array[i], dec: 4))
        }
        print()
    }
    
    func joinArrayRows(arrays:[[Float]], at:Int, n:Int) -> [Float] {
        var result:[Float] = []
        for i in 0..<n {
            let row = arrays[at + i]
            result.append(contentsOf: row)
        }
        return result
    }

    func calcNoteOnsets(frames:[[Float]], samplingRate: Float, fitToExpected:Bool) -> [NoteOnset] {
        //let givenValues:[Float] = [1,1,0.5,0.5,1,  2,2,  1,1,1,1,  4 ] //ex.1
        let givenValues:[Float] = [1,1,1,1,1 ] //seq c -> G

        //let givenValues = [1,0.5,0.5,1,1,   1,1,1,1,   2,1,1,  4] //ex.4
        //let givenValues = [2,2,  1,1,2,   0.5,0.5,2,1,  4] //ex.7
        //let givenValues = [1,1,2, 2,2, 1,0.5,0.5,1,1,   4] //ex.9
        //let givenValues = [2, 2, 1, 1, 2, 0.5, 0.5, 2, 1, 4] //ex.27

        var noteOnsets:[NoteOnset] = []
        var framesIndex = 10
        let initialThresholdIncrease:Float = 1.5
        var currentThresholdIncrease = initialThresholdIncrease
        
        var framesPerUnitValue:Int?
        var nextPredictedIndex:Int?
        var continueAnalysis = true
        var thresholdAdjustCtr = 0
        
        while continueAnalysis {

            let noteOnset = getNoteOnsetFrom(frames: frames,
                                             startIndex: framesIndex,
                                             thresholdIncrease: currentThresholdIncrease)
            guard let noteOnset = noteOnset else {
                print("No next note")
                break
            }
            noteOnset.onsetSeconds = Float(noteOnset.onsetFrame) * Float(samplesPerFrame) / samplingRate

            if noteOnsets.count > 0 {
//                print("\ngotIndex:", noteOnset.onsetFrame, "predicted:",
//                      nextPredictedIndex ?? "",
//                      "threshold", str(currentThresholdIncrease, dec: 6),
//                      "tempo", framesPerUnitValue ?? ""
//                )

                if fitToExpected && nextPredictedIndex != nil {
                    let discrep = noteOnset.onsetFrame - nextPredictedIndex!
                    //let allowed1 = Int(Float(framesPerUnitValue!) * givenValues[noteOnsets.count-1] * 0.5)
                    let allowed = Int(Float(framesPerUnitValue!) * 0.40)
                    if abs(discrep) >= allowed {
                        thresholdAdjustCtr += 1
                        if thresholdAdjustCtr > 100  {
                            print("Infinite loop at note frame index \(framesIndex), Stopping")
                            continueAnalysis = false
                            break
                        }
                        if discrep > 0 {
                            //Found an onset too late and skipped the correct increase.
                            //Look for the expected note as a smaller increase earlier.
                            //OR the expected note was played too late in which case continued
                            //reduction of the current threshold will never find the expected note
                            currentThresholdIncrease *= 0.9
                        }
                        else {
                            //Found an amplitude increase too soon
                            //Look for a larger increase later on
                            currentThresholdIncrease *= 1.1
                        }
                        if currentThresholdIncrease < 0.01 {
                            //Now give up looking for the expected note before the last one just found.
                            //without break: Assume the last one found is the right note but delayed after what was expected.
                            //with break: Just give up
                            break
                        }
                        else {
                            continue
                        }
                    }
                    else {
                        thresholdAdjustCtr = 0
                    }
                }
                
                let framesDiff:Int = noteOnset.onsetFrame - noteOnsets[noteOnsets.count-1].onsetFrame
                noteOnsets[noteOnsets.count - 1].frameCount = framesDiff
                
                if noteOnsets.count >= 1 {
                    //calculate tempo over all the notes played
                    if fitToExpected {
                        var tempos:[Float] = []
                        for i in 0..<noteOnsets.count  {
                            let tempoVal:Float
                            if i == noteOnsets.count - 1 {
                                tempoVal = Float(framesDiff) / Float(givenValues[i])
                            }
                            else {
                                tempoVal = Float(noteOnsets[i].frameCount!) / Float(givenValues[i])
                            }
                            tempos.append(tempoVal)
                            if tempos.count > 2 {
                                //just take the most recent tempos
                                break
                            }
                        }
                        framesPerUnitValue = Int(getAbsoluteAvg(tempos))
                    }
                    else {
                        //Only the first note of expected is provided
                        //Its provided in order to calculate the framesPerUnitValue based on only the first note
                        if framesPerUnitValue == nil {
                            framesPerUnitValue = Int(Float(framesDiff) / Float(givenValues[0]))
                        }
                    }
                }
                
                let value = Float(framesDiff) / Float(framesPerUnitValue!)
                noteOnsets[noteOnsets.count - 1].value = value
                noteOnsets[noteOnsets.count - 1].durationSeconds = (Float(framesDiff) * Float(samplesPerFrame)) / samplingRate
                
                noteOnsets.append(noteOnset)
                if fitToExpected {
                    if noteOnsets.count == givenValues.count {
                        break
                    }
                    nextPredictedIndex = noteOnset.onsetFrame + Int((givenValues[noteOnsets.count-1] * Float(framesPerUnitValue!)))
                }
                framesIndex = noteOnset.onsetFrame + 4 //???? TODO
                currentThresholdIncrease = initialThresholdIncrease
                
                print(" Stored -->", noteOnset)
                if noteOnset.onsetFrame == 136 {
                    print("+++++++++++++")
                }
            }
            else {
                noteOnsets.append(noteOnset)
                framesIndex = noteOnset.onsetFrame + 10
            }

        }
        return noteOnsets
    }
        
    func getFrequencies(completionHander:  (() -> Void)? = nil) {
        frequencyReadings = []
        
        let url = getUrl()
        self.player = AudioPlayer()
        do {
            try self.player!.load(url: url!)
        } catch {
            print("Error loading the audio file: \(error.localizedDescription)")
            return
        }
        
        pitchTap = PitchTap(player!) { pitches, amplitudes in
            ///Buffer Size: The handleTapBlock is called every time a buffer of audio data is processed. If the buffer size is set to, say, 512 samples, the callback will be triggered every 512 samples.

            ///Sample Rate: The sample rate determines how many samples are in one second of audio. Commonly, this is 44.1 kHz (44,100 samples per second for CD quality audio). So if you have a buffer size of 512 samples at a 44.1 kHz sample rate, the handleTapBlock would be called roughly every
            ///512/44,100=0.0116 seconds, or about every 11.6 milliseconds.
            ///
            //if amplitudes[0] > 0.1 {
                let now:Int64 = Int64(Date().timeIntervalSince1970 * 1000)
                let timeSecs = Float(now - self.startTimeMs) / 1000.0
                
                var log = ""
                if false {
                    log += "FreqCall:\(self.handlerCallNum)"
                    log += "\tTime:\(String(format: "%.2f", timeSecs))"
                    log += "\tAmplitude: \(self.str(amplitudes[0]))"
                    log += "\tPitch: \(self.str(pitches[0].magnitude.magnitude)) Hz"
                }
                else {
                    log += "\(String(format: "%.2f", timeSecs))  ,  \(self.str(amplitudes[0])) , \(self.str(pitches[0].magnitude.magnitude))"
                }
                self.frequencyReadings.append(FrequencyReading(time: timeSecs,
                                                               magnitude: amplitudes[0],
                                                      frequency: pitches[0].magnitude.magnitude))
                print(log)
                self.lastPitch = pitches[0].magnitude
            //}
            self.handlerCallNum += 1
        }

        engine.output = player
        self.startTimeMs = Int64(Date().timeIntervalSince1970 * 1000)
        player!.completionHandler = {
            self.player!.stop()
            self.pitchTap.stop()
            print("Playback has finished!")
            if let completionHander = completionHander {
                completionHander()
            }
        }

        do {
            try engine.start()
            pitchTap.start()
            player!.play()
        } catch {
            print("Error starting the AudioEngine: \(error.localizedDescription)")
        }
    }
    
    func getNoteName(pitch: Float) -> String{
        let noteFrequencies = [16.35, 17.32, 18.35, 19.45, 20.6, 21.83, 23.12, 24.5, 25.96, 27.5, 29.14, 30.87]
        let noteNamesWithSharps = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let noteNamesWithFlats = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]

        var frequency = pitch
        while frequency > Float(noteFrequencies[noteFrequencies.count - 1]) {
            frequency /= 2.0
        }
        while frequency < Float(noteFrequencies[0]) {
            frequency *= 2.0
        }

        var minDistance: Float = 10000.0
        var index = 0

        for possibleIndex in 0 ..< noteFrequencies.count {
            let distance = fabsf(Float(noteFrequencies[possibleIndex]) - frequency)
            if distance < minDistance {
                index = possibleIndex
                minDistance = distance
            }
        }
        let octave = Int(log2f(pitch / frequency))
        return "\(noteNamesWithSharps[index])\(octave)"
        //data.noteNameWithFlats = "\(noteNamesWithFlats[index])\(octave)"
    }

    func matchFrequenciesToOnsets(frequencyReadings:[FrequencyReading], noteOnsets:[NoteOnset]) {
        for noteOnset in noteOnsets {
            var lowest:Float?
            var lowestIndex:Int = 0
            for i in 0..<frequencyReadings.count {
                
                let frequencyReading = frequencyReadings[i]
                if frequencyReading.magnitude < 0.28 {
                    continue
                }
                let diff = abs(noteOnset.onsetSeconds + 0.20 - frequencyReading.time) //TODO ????
                if lowest == nil || diff < lowest! {
                    lowest = diff
                    lowestIndex = i
                }
            }
            noteOnset.frequency = frequencyReadings[lowestIndex].frequency
            noteOnset.frequencyMagnitude = frequencyReadings[lowestIndex].magnitude
            noteOnset.noteName = getNoteName(pitch: noteOnset.frequency!)
        }
    }
    
    ///Note onsets are analysed successivly in two modes -
    ///
    ///1) With guidance from the expected notes. The first note onset analysis of the student's playing
    ///This allows the analysis to look for the sometimes small amplitude increases that signify a new note. i.e. flag a correct playing of note values even if they are hard to detect.
    ///Amplitude changes are often small between quavers since the sound from #1 is still ringinging when #2 starts.
    ///Guidance causes the analysis to detect smaller changes when it knows to expect a note but does not find it when looking at coarser amplitude changes
    ///
    ///2) Without guidance - if 1) cannot make a good match to the expected notes (e.g. the student played the note values wrongly) make a 2nd pass without guidance
    ///This allows the app to at least provide some sort of feedback to the student as to what it 'thinks' it heard.
    
    func analyzeFile() {
        //let name = "iPhone_Ex1_Piano" //SineUp_PianoDown_Octave" //Quarter1Eigth2_Octave"
        let url = getUrl()
        do {
            let audioFile = try AVAudioFile(forReading: url!)
            let durationSeconds = Float(audioFile.length) / Float(audioFile.fileFormat.sampleRate)
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
            let frameDurationSeconds = durationSeconds / Float(frameCount)
            
            var amplitudeFrames: [[Float]] = []
            
            for segmentIndex in 0..<frameCount {
                //TODO shoudl overlap segments into processing
                let startSample = segmentIndex * Int(self.samplesPerFrame)
                let endSample = startSample + Int(self.samplesPerFrame)
                var frame: [Float] = []
                for sampleIndex in startSample..<endSample {
                    let sample = channelData[Int(sampleIndex)]
                    //let sample = abs(channelData[Int(sampleIndex)]) //   TODO - is absolute OK - NO - time domain values should be zero centered
                    frame.append(sample)
                }
                //print("\(amplitudeFrames.count),   \(str(getAvg(frame),dec:4))")
                amplitudeFrames.append(frame)
            }
            
            print("\nTotalSamples:\(totalSamples), Duration:\(str(durationSeconds)) seconds, SamplingRate:\(audioFile.fileFormat.sampleRate)")
            print("  FrameLength:\(samplesPerFrame) TotalFrames:\(amplitudeFrames.count), FrameDuration:\(str(frameDurationSeconds))")

            ///calculate with and without guidance from the question score
            for i in 0..<1 {
                let noteOnsets = calcNoteOnsets(frames: amplitudeFrames,
                                                samplingRate: Float(audioFile.fileFormat.sampleRate),
                                                fitToExpected: i==0)
                
                self.getFrequencies {
                    self.matchFrequenciesToOnsets(frequencyReadings: self.frequencyReadings, noteOnsets: noteOnsets)
                    print("\n===== \(i) Returned notes =====")
                    for i in 0..<noteOnsets.count {
                        let noteOnset = noteOnsets[i]
                        print(i, noteOnset, terminator: " ")
                        print()
                    }
                    print("\n")
                }
                break
            }
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
