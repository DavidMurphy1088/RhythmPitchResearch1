import SwiftUI
import Foundation
import AVFoundation
import Accelerate



class ValWithTag : Hashable {
    var idx:Int
    //var val:Float
    var val:Double
    var tag:Int
    
    init(idx:Int, val:Double, _ tag:Int) {
        self.idx = idx
        self.val = val
        self.tag = tag
    }
    init(idx:Int, val:Float, _ tag:Int) {
        self.idx = idx
        self.val = Double(val)
        self.tag = tag
    }

    static func == (lhs: ValWithTag, rhs: ValWithTag) -> Bool {
        return lhs.idx == rhs.idx
    }

    func hash(into hasher: inout Hasher) {
            hasher.combine(val)
            hasher.combine(tag)
    }
}

class NoteOffset {
    var startSegment:Int
    var endSegment:Int
    var aplitudeChangePercent:Double
    
    init(startSegment:Int, endSegment:Int, amplitudeChangePercent:Double) {
        self.startSegment = startSegment
        self.endSegment = endSegment
        self.aplitudeChangePercent = amplitudeChangePercent
    }
    
    func duration() -> Double {
        return Double(endSegment - startSegment)
    }
}

class Audio : ObservableObject {
    var audioBufferFrames:[Float] = []
    
    var segmentAverages:[Float] = []
    //@Published var segmentAveragesPublished:[ValWithTag] = []
    @Published var segmentAveragesPublished:[ValWithTag] = []

    var fourierTransformOutput:[Double] = []
    var fourierImaginaryPart:[Double] = []
    var splitComplex:DSPDoubleSplitComplex?
    @Published var fourierTransformOutputPublished:[ValWithTag] = []

    //var noteStartSegments:[Int] = []
    @Published var noteStartSegmentsPublished:[ValWithTag] = []
    @Published var noteOffsets:[NoteOffset] = []
    
    //var milliSecondsPerSegment:Double = 0.0
    let numberFormatter = NumberFormatter()
    var segmentsPerSlice = 1
    var milliSecondsPerSegment = 0.0
    var publishedCtr = 0
    var fileName:String = ""
    
    func str(_ inVal:Double) -> String {
        return String(format: "%.2f", inVal)
    }
    
    func str(_ inVal:Int) -> String {
        numberFormatter.string(from: NSNumber(value: inVal)) ?? ""
    }
    
    func segmentAndAverage(array: [Float], segmentLength: Int) -> [Float] {
        var averages: [Float] = []
        for i in stride(from: 0, to: array.count, by: segmentLength) {
            let endIndex = min(i + segmentLength, array.count)
            let segment = Array(array[i..<endIndex])
            let sum = segment.reduce(0, +)
            let average = sum / Float(segment.count)
            averages.append(average)
        }
        return averages
    }
    
    func segmentAndAverage(array: [Double], segmentLength: Int) -> [Double] {
        var averages: [Double] = []
        for i in stride(from: 0, to: array.count, by: segmentLength) {
            let endIndex = min(i + segmentLength, array.count)
            let segment = Array(array[i..<endIndex])
            let sum = segment.reduce(0, +)
            let average = sum / Double(segment.count)
            averages.append(average)
        }
        return averages
    }
    
    func readFile(name:String) {
        self.fileName = name
        numberFormatter.numberStyle = .decimal
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            print("File  not found in the app bundle.")
            return
        }
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let durationSeconds = Double(audioFile.length) / audioFile.fileFormat.sampleRate
            let frames = AVAudioFrameCount(audioFile.length)
            let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(audioFile.length))
            guard audioBuffer != nil else {
                return
            }
            try audioFile.read(into: audioBuffer!)
            if let floatChannelData = audioBuffer?.floatChannelData {
                let channelCount = Int(audioFile.processingFormat.channelCount)
                let frameLength = Int(audioBuffer!.frameLength)
                var ctr = 0
                
                // Iterate over the audio frames and access the sample values
                for frame in 0..<frameLength {
                    var channelTotal = 0.0
                    for channel in 0..<channelCount {
                        let sampleValue = Double(floatChannelData[channel][frame])
                        channelTotal += sampleValue
                    }
                    self.audioBufferFrames.append(Float(channelTotal))
                }
            }
            //self.audioBufferFrames = generateSineCurveArray(length: audioBufferFrames.count)
            print("readFile", name,
                  "\n  duration secs:", str(durationSeconds),
                  "\n  sample rate:", Int(audioFile.fileFormat.sampleRate),
                  "\n  frames:", frames)
        }
        catch {
            print("Error loading file: \(error.localizedDescription)")
        }
    }
    
    //Segment the frames into an array of segment averages
    func segmentFile(name:String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            print("File  not found in the app bundle.")
            return
        }
        let audioFile:AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: url)
        }
        catch {
            print("Error loading file: \(error.localizedDescription)")
            return
        }
        
        let normalize = false
        var segmentSize = normalize ? 100 : 10
        let durationSeconds = Double(audioFile.length) / audioFile.fileFormat.sampleRate
        let numSegments = self.audioBufferFrames.count / segmentSize
        self.milliSecondsPerSegment = (durationSeconds * 1000.0) / Double(numSegments)

        let segmentAverages = segmentAndAverage(array: self.audioBufferFrames, segmentLength: segmentSize)
        let timeFilterMSStart = 2000.0
        let timeFilterMSEnd = 4000.0
        let startSegment:Int = Int(timeFilterMSStart / milliSecondsPerSegment)
        let endSegment:Int = Int(timeFilterMSEnd / milliSecondsPerSegment)
        if false {
            self.segmentAverages = Array(segmentAverages[startSegment...endSegment])
        }
        else {
            self.segmentAverages = segmentAverages
        }
              
        print("SegmentFile",
              "\n  SegmentSize:", segmentSize,
              "\n  NumSegments:", numSegments,
              "\n  MS Per Segment:", str(milliSecondsPerSegment)
        )
    }

    //Find the note onsets by looking for amplitude bumps in slices of the segment averages
    func getNoteOnsets(name:String) {
        var lastNoteSegmentIdx:Int?
        
        //=============== Parameters ==============
        
        self.segmentsPerSlice = 100 // how many segments per slice either side of analysis point
        //self.segmentsPerSlice = 300 // how many segments per slice either side of analysis point
        let segmentAdvance = 0.25 // how many segments to move the analysis point forward each iteration
        let shortestNote = 0.25 //shortest note value, how far to jump ahead after a note onset detected
        //let shortestNote = 0.05 //shortest note value, how far to jump ahead after a note onset detected

        let amplitudeMinimumRequired:Float = 0.1 //What percenatge of the maximum is required to trigger note onset. Added to avoid phantom onsets before and after melody plays
        
        //let amplitudeChangePercentThreshold = 1.5 //trigger note onset on this change in amplitude from previous segments slice
        //let amplitudeChangePercentThreshold = 0.60 //trigger note onset on this change in amplitude from previous segments slice
        //let amplitudeChangePercentThreshold = 0.20 //trigger note onset on this change in amplitude from previous segments slice
        let amplitudeChangePercentThreshold = 0.10 //trigger note onset on this change in amplitude from previous segments slice
        //let amplitudeChangePercentThreshold = 0.05 //TOO LOW trigger note onset on this change in amplitude from previous segments slice

        let lookAheadMS = 50 //UNUSED - How many millisec to lookahead to confirm presence of note (or is amplitude change just a bump)
        let amplitudeChangeThreshold:Float = 2.0 //UNUSED - How amplitude must change based on the max amplitude in the file
        //let amplitudeChangeThreshold = maxAmplitude * 0.02
        //let amplitudeChangeThreshold = maxAmplitude * 0.25
        
        // ================ Questions ============
        //is first segmet of note onset too early
        //why use max amplitude to set threshold - use % increase from last segment
        
        let maxAmplitude:Float = self.segmentAverages.max() ?? 0
        //let amplitudeChangeThresholdValue = maxAmplitude * amplitudeChangeThreshold
        let amplitudeThresholdValue = maxAmplitude * amplitudeMinimumRequired
        var segmentIdx = segmentsPerSlice

        self.noteOffsets = []

        while segmentIdx < self.segmentAverages.count {
            let prev = subArray(array: self.segmentAverages, at: segmentIdx, fwd:false, len: segmentsPerSlice)
            let next = subArray(array: self.segmentAverages, at: segmentIdx, fwd:true, len: segmentsPerSlice)
            let prevAvg = prev.reduce(0, +)
            let nextAvg = next.reduce(0, +)
            //let pstd:Float = getStandardDeviation(prev) ?? 1
            //let nstd:Float = getStandardDeviation(next) ?? 1

            let amplitudeChangePercent:Double = Double((nextAvg - prevAvg) / prevAvg)
            
            //if nextAvg - prevAvg > amplitudeChangeThresholdValue {
            if nextAvg > amplitudeThresholdValue && amplitudeChangePercent > amplitudeChangePercentThreshold {
                //let endLookAhead = segmentIdx + lookaheadSegments
                //if endLookAhead < self.segmentAverages.count {
                    //let lookAhead = subArray(array: self.segmentAverages, at: segmentIdx, fwd:true, len: lookaheadSegments)
                    //let lookAheadAvg = lookAhead.reduce(0, +)
                    //let diff = lookAheadAvg - nextAvg
                    //if abs(diff) < 0.25 * nextAvg {
                        //save the note location and value
                    if let lastNoteSegmentIdx = lastNoteSegmentIdx {
                        let lastNoteOffset = NoteOffset(startSegment: lastNoteSegmentIdx, endSegment: segmentIdx,
                                                        amplitudeChangePercent: amplitudeChangePercent)
                        self.noteOffsets.append(lastNoteOffset)
                        
                        //DO FFT on the note duration
                        let fftSegs:Int = Int(Double(segmentIdx - lastNoteSegmentIdx) / 3.0)
                        let noteSegments = Array(segmentAverages[segmentIdx...segmentIdx + fftSegs])
                        self.performFourierTransform(inArray: noteSegments, publish: self.noteOffsets.count == 3)
                        
                        print ("    FFT segStart:", lastNoteSegmentIdx, "len:", noteSegments.count)
                    }
                //}
                lastNoteSegmentIdx = segmentIdx
                
                //jump ahead to next note, assume shortest note is value 1/4 of 1.0
                let segmentsPerSec = 1000.0 / Double(self.milliSecondsPerSegment)
                let jumpAhead = max(Int(segmentsPerSec * shortestNote), 1)
                segmentIdx += jumpAhead
            }
            else {
                segmentIdx += Int(Double(self.segmentsPerSlice) * segmentAdvance)
            }
        }
        if let lastNoteSegmentIdx = lastNoteSegmentIdx {
            let lastNoteOffset = NoteOffset(startSegment: lastNoteSegmentIdx,
                                            endSegment: segmentIdx,
                                            amplitudeChangePercent: 0)
            noteOffsets.append(lastNoteOffset)
        }
        
        print("")
        print("segments per Slice", self.segmentsPerSlice, "Amplitude change", amplitudeChangeThreshold)
        print("=== Notes")
        
        var first:Double = 0
        for n in 0..<noteOffsets.count {
            let note = noteOffsets[n]
            let segs:Int = note.endSegment - note.startSegment
            let value = Double(segs) * Double(self.milliSecondsPerSegment) / Double(1000)
            if first == 0 {
                first = value
            }
            print(n,
                  "\tStartSeg:", str(note.startSegment),
                  "\tEndSeg:", str(note.endSegment),
                  "\tampli_%:", str(note.aplitudeChangePercent),
                  "\tNumSegments", str(segs),
                  "\tValue", str(value / first)
            )
        }
        analyseCorrect(noteOffsets: noteOffsets)
    }
    
    func analyseCorrect(noteOffsets:[NoteOffset]) {
        let cnt = self.fileName.count
        let exName = fileName.prefix(cnt-7)
        let exampleData = ExampleData().getData(key: "Grade 1.Playing.\(exName)")
        var recordedIndex = 0
        var adjust:Double?
        let correctNotes = getCorrectNotes(fileName: self.fileName)
        print("\n=== Correct === \(self.fileName)")
        for correctNote in correctNotes()
            if recordedIndex >= noteOffsets.count {
                print("=============== Too few notes")
                break
            }

            let recordedNote = noteOffsets[recordedIndex]
            if recordedIndex == 0 {
                let segs = recordedNote.duration()
                adjust = segs / correctNote.getValue()
            }

            let diff = recordedNote.duration() - correctNote.getValue()
            let adjDiff = diff / adjust!

            let percentDiff = abs(adjDiff - correctNote.getValue()) / correctNote.getValue()
            let ok = percentDiff < 0.15
            print("  ctr:", correctCtr, "correctValue:", correctNote.getValue(),
                  "\t\tvalue:", str(adjDiff), "\t%:\(str(percentDiff))", "\t\tOK:", ok)
            recordedIndex += 1
            correctCtr += 1
    }
    
    func subArray(array:[Float], at:Int, fwd: Bool, len:Int) -> [Float] {
        var res:[Float] = []
        let sign = 1.0 //array[at] < 0.0 ? -1.0 : 1.0
        if fwd {
            if at + len >= array.count - 1 {
                return res
            }
            let to = at+len
            for i in at..<to {
                res.append(array[i] * array[i] * Float(sign))
            }
        }
        else {
            if at - len < 0 {
                return res
            }
            let from = at-len
            for i in from..<at {
                res.append(array[i] * array[i] * Float(sign))
            }
        }
        return res
    }
    
    func publish(offset:Int, windowSizePercent:Double) {
        DispatchQueue.main.async {
            let startIdx = offset
            var pointsToPublish = Int(Double(self.segmentAverages.count) * windowSizePercent / 100.0)
            pointsToPublish = pointsToPublish - self.publishedCtr
            self.publishedCtr += 1

            self.segmentAveragesPublished = []
            
            var segCtr = 0
            for i in 0..<pointsToPublish {
                let idx = offset + i
                if idx < self.segmentAverages.count {
                    //self.segmentAveragesPublished.append(ValWithTag(i, self.segmentAverages[idx], 1))
                    self.segmentAveragesPublished.append(ValWithTag(idx:idx, val:self.segmentAverages[idx], 0))
                    segCtr += 1
                }
            }
            //print("START published ", self.segmentAveragesPublished.count)

            //publish onsets
            var noteCtr = 0
            for noteOffset in self.noteOffsets {
                let first = noteOffset.startSegment - offset - self.segmentsPerSlice
                let last  = noteOffset.startSegment - offset + self.segmentsPerSlice
                if first >= 0 && last < self.segmentAveragesPublished.count {
                    self.segmentAveragesPublished[first].tag = 2
                    self.segmentAveragesPublished[noteOffset.startSegment - offset].tag = 1
                    self.segmentAveragesPublished[last].tag = 2
                    noteCtr += 1
                }
            }
            
        }
    }
    
    func publishFFT(offset:Int, windowSizePercent:Double) {
        //Fourier
        self.fourierTransformOutputPublished = []
        var ctr = 0
        for f in self.fourierTransformOutput {
            self.fourierTransformOutputPublished.append(ValWithTag(idx:ctr, val:f, 0))
            ctr += 1
        }
    }
    
    func getStandardDeviation(_ array: [Float]) -> Float? {
        let count = Float(array.count)
        
        // Calculate the mean
        let sum = array.reduce(0, +)
        let mean = sum / count
        
        // Calculate the sum of squared differences from the mean
        let squaredDifferencesSum:Float = array.reduce(0) { (result, value) in
            let difference = value - mean
            return result + difference * difference
        }
//        let squaredDifferencesSum
//        for value in array {
//            let diff = value - mean
//
//        }
        
        // Calculate the variance
        let variance = squaredDifferencesSum / count

        // Calculate the standard deviation
        let standardDeviation = sqrt(variance)
        
        return standardDeviation
    }
    
    func analyse(name:String) {
        readFile(name: name)
        segmentFile(name:name)
        getNoteOnsets(name: name)
    }
    
    func analyseAll() {
        for i in 1..<11 {
            analyse(name: "Example \(i)_SkyPad")
        }
    }
    
    //================= Filters
    
//    func bandPassFilter(segments: [[Float]]) -> [[Float]] {
//        let filteredSegments = segments.map { segment in
//            return segment.filter { value in
//                let midiPitch = convertToMIDIPitch(value)
//                return midiPitch >= 60 && midiPitch <= 72
//            }
//        }
//        return filteredSegments
//    }
//
//    func convertToMIDIPitch(_ value: Float) -> Int {
//        let midiPitch = Int(value * 127) // Assuming the range of values is normalized from 0 to 1
//        return midiPitch
//    }
    func calculateAverage(of array: [Float]) -> Float {
        guard !array.isEmpty else {
            return 0.0 // Return 0 if the array is empty to avoid division by zero
        }
        
        let sum = array.reduce(0, +)
        let average = sum / Float(array.count)
        
        return average
    }
    
    func normalizeAudioFile(audioData: [Float], segmentLength: Int) -> [[Float]] {
        let totalSegments = audioData.count / segmentLength
        var normalizedSegments: [[Float]] = []
        
        for segmentIndex in 0..<totalSegments {
            let startIndex = segmentIndex * segmentLength
            let endIndex = startIndex + segmentLength
            
            let segment = Array(audioData[startIndex..<endIndex])
            let maxValue = segment.max() ?? 1.0
            
            let normalizedSegment = segment.map { value in
                return value / maxValue
            }
            
            normalizedSegments.append(normalizedSegment)
        }
        
        return normalizedSegments
    }
    
    // ================ Fourier =================
    func arrayToFloat(_ doubleArray: [Double]) -> [Float] {
        return doubleArray.map { Float($0) }
    }
    
    func arrayToDouble(_ doubleArray: [Float]) -> [Double] {
        return doubleArray.map { Double($0) }
    }

    func performFourierTransform(inArray:[Float], publish:Bool) {
        var fft = FFT()

        let n = 512 // Should be power of two for the FFT
        let frequency1 = 4.0
        let phase1 = 0.0
        let amplitude1 = 8.0
        let seconds = 2.0
        let fps = Double(n)/seconds

//        var sineWave = (0..<n).map {
//            amplitude1 * sin(2.0 * .pi / fps * Double($0) * frequency1 + phase1)
//        }

        fft.calculate(self, arrayToDouble(inArray), publish: publish)
    }

    func getCorrectNotes(fileName:String) -> [Note] {
        let cnt = self.fileName.count
        let exName = fileName.prefix(cnt-7)
        let exampleData = ExampleData().getData(key: "Grade 1.Playing.\(exName)")
        var result:[Note] = []
        if let entries = exampleData {
            var correctCtr = 0
            for entry in entries {
                if entry is Note {
                    let correctNote = entry as! Note
                    result.append(correctNote)
                }
            }
        }
        return result
    }
}
