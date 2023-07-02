import SwiftUI
import Foundation
import AVFoundation
import Accelerate

enum PointType {
    case segment
    case noteOffset
    //case noteOffsetSacn
    case correctNoteActual
    case correctNoteSynched
    case error
    case none
}

class ValWithTag : Hashable {
    let id = UUID()
    var xValue:Int
    //var val:Float
    var val:Double
    var pointType:PointType
    
    init(xValue:Int, val:Double, pointType:PointType) {
        self.xValue = xValue
        self.val = val
        self.pointType = pointType
    }
//    init(xValue:Int, val:Float, tag:Int) {
//        self.xValue = xValue
//        self.val = Double(val)
//        self.tag = tag
//    }

    static func == (lhs: ValWithTag, rhs: ValWithTag) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
            hasher.combine(val)
            hasher.combine(pointType)
    }
}

class NoteOffset {
    var startSegment:Int
    var endSegment:Int
    var aplitudeChangePercent:Double
    var pointType:PointType = PointType.none
    
    init(startSegment:Int, endSegment:Int, amplitudeChangePercent:Double) {
        self.startSegment = startSegment
        self.endSegment = endSegment
        self.aplitudeChangePercent = amplitudeChangePercent
    }
    
    func durationSegments() -> Int {
        return endSegment - startSegment
    }
}

class Audio : ObservableObject {
    var audioBufferFrames:[Float] = []
    
    var segmentAverages:[Float] = []
    var noteOffsets:[NoteOffset] = []
    var correctNoteOffsets:[NoteOffset] = []
    
    @Published var segmentAveragesCountPublished:Int = 0
    @Published var segmentAveragesPublished:[ValWithTag] = []
    @Published var markersPublished:[ValWithTag] = []

    //@Published var noteStartSegmentsPublished:[ValWithTag] = []
    //@Published
    
    var fourierTransformOutput:[Double] = []
    var fourierImaginaryPart:[Double] = []
    var splitComplex:DSPDoubleSplitComplex?
    @Published var fourierTransformOutputPublished:[ValWithTag] = []
    var correctNotes:[Note] = []
    
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
        self.correctNotes = getCorrectNotes(fileName: self.fileName)

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
        
        DispatchQueue.main.async {
            self.segmentAveragesCountPublished = self.segmentAverages.count
        }
    }

    //Find the note onsets by looking for amplitude bumps in slices of the segment averages
    func getNoteOnsets(name:String) {
        var lastNoteSegmentIdx:Int?
        
        //=============== Parameters ==============
        
        self.segmentsPerSlice = 100 //100 // how many segments per slice either side of analysis point
        //self.segmentsPerSlice = 300 // how many segments per slice either side of analysis point
        let segmentAdvance = 0.25 // how many segments to move the analysis point forward each iteration
        let shortestNote = 0.25 //shortest note value, how far to jump ahead after a note onset detected
        //let shortestNote = 0.05 //shortest note value, how far to jump ahead after a note onset detected

        //let amplitudeMinimumRequired:Float = 0.1 //What percenatge of the maximum is required to trigger note onset. Added to avoid phantom onsets before and after melody plays
        let amplitudeMinimumRequired:Float = 0.3

        //let amplitudeChangePercentThreshold = 1.5 //trigger note onset on this change in amplitude from previous segments slice
        //let amplitudeChangePercentThreshold = 0.60 //trigger note onset on this change in amplitude from previous segments slice
        //let amplitudeChangePercentThreshold = 0.20 //trigger note onset on this change in amplitude from previous segments slice
        //let amplitudeChangePercentThreshold = 0.10 //trigger note onset on this change in amplitude from previous segments slice
        let amplitudeChangePercentThreshold = 0.20 //trigger note onset on this change in amplitude from previous segments slice

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
        let correctNotes = getCorrectNotes(fileName: self.fileName)
        var quarterNoteSegments:Int = 0
        
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
                        
                        //Calc what segment the next note should be at
                        if self.noteOffsets.count == 1 {
                            quarterNoteSegments = segmentIdx - lastNoteSegmentIdx
                        }
                        //f
                        
                        //DO FFT on the note duration
                        //let fftSegs:Int = Int(Double(segmentIdx - lastNoteSegmentIdx) / 3.0)
                        //let noteSegments = Array(segmentAverages[segmentIdx...segmentIdx + fftSegs])
                        //self.performFourierTransform(inArray: noteSegments, publish: self.noteOffsets.count == 3)
                        //print ("    FFT segStart:", lastNoteSegmentIdx, "len:", noteSegments.count)
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
        alignToCorrect()
        //analyseCorrect(noteOffsets: noteOffsets)
    }
    
    func publish(startOffset:Int, magnifyPercent:Double, windowSizePercent:Double) {

        DispatchQueue.main.async {
            self.segmentAveragesPublished = []
            self.markersPublished = []
            
            var startIndex = startOffset //Int(Double(self.segmentAverages.count) * offsetPercent / 100.0)
            if self.noteOffsets.count > 0 { //}&& startOffset = 0.0 {
                if startIndex < self.noteOffsets[0].startSegment {
                    startIndex = self.noteOffsets[0].startSegment - 1000
                }
            }
            
            // segments
            let endIndex = startIndex + Int(Double(self.segmentAverages.count) * windowSizePercent / 100.0)
            let mod = 100.0 / magnifyPercent
            if endIndex > startIndex {
                for i in startIndex..<endIndex {
                    if i % Int(mod) == 0 {
                        if i < self.segmentAverages.count {
                            self.segmentAveragesPublished.append(ValWithTag(xValue:i, val: Double(self.segmentAverages[i]), pointType: .segment))
                        }
                    }
                }
            }
            
            // note offsets
            var firstOffset:NoteOffset?
            for i in 0..<self.noteOffsets.count {
                let note = self.noteOffsets[i]
                self.markersPublished.append(ValWithTag(xValue: note.startSegment, val: 0,
                                                        pointType: note.aplitudeChangePercent > 100.0 ? PointType.noteOffset : PointType.noteOffset))
                if i==0 {
                    firstOffset = note
                }
            }
        
            // correct notes
            if false {
                if let firstOffset = firstOffset {
                    var correctSegment = firstOffset.startSegment
                    for correctNote in self.correctNotes {
                        self.markersPublished.append(ValWithTag(xValue: correctSegment, val: 0, pointType: PointType.correctNoteActual))
                        let correctValue = correctNote.getValue()
                        //print ("--->Correct:", correctNote.sequence, correctNote.midiNumber, correctNote.getValue(), correctNote.getNoteValueName())
                        var len = Double(firstOffset.durationSegments()) * correctValue
                        correctSegment += Int(len)
                    }
                }
            }

            // correct note offsets
            for correctNote in self.correctNoteOffsets {
                self.markersPublished.append(ValWithTag(xValue: correctNote.startSegment, val: 0, pointType: PointType.correctNoteSynched))
            }
        }
    }

    //Make a synched set of note offsets based on the correct note values
    func alignToCorrect() {
        self.correctNoteOffsets = []
        var n = 0
        var firstSegmentLength:Int = 0
        var recordedIndex:Int = 0
        var correctIndex:Int = 0
        print("\nAlign to Correct ===============")
        
        for noteOffset in self.noteOffsets {
            if n == 0 {
                firstSegmentLength = Int(noteOffset.durationSegments())
                correctNoteOffsets.append(NoteOffset(startSegment: noteOffset.startSegment, endSegment: noteOffset.endSegment, amplitudeChangePercent: 0))
                recordedIndex = noteOffset.endSegment
                correctIndex = noteOffset.endSegment
                n = n+1
                continue
            }
            let  diffSegments:Int = recordedIndex - correctIndex
            let diffPercent:Double = abs(Double(diffSegments)) / Double(firstSegmentLength)
            print("offset num:", n, "segment:", recordedIndex, "diff:", str(diffPercent))
            
            if diffPercent > 0.30 {
                print("  error note midi:", correctNotes[n].midiNumber, "value:", correctNotes[n].getValue())
                correctNoteOffsets.append(NoteOffset(startSegment: noteOffset.startSegment - diffSegments, endSegment: noteOffset.endSegment, amplitudeChangePercent: 0))
                break
            }
            else {
                correctNoteOffsets.append(NoteOffset(startSegment: noteOffset.startSegment, endSegment: noteOffset.endSegment, amplitudeChangePercent: 0))
            }

            correctIndex = recordedIndex + Int(self.correctNotes[n].getValue() * Double(firstSegmentLength))
            recordedIndex += noteOffset.durationSegments()

            n += 1
        }
    }
    
    func analyseCorrect(noteOffsets:[NoteOffset]) {
        let cnt = self.fileName.count
        let exName = fileName.prefix(cnt-7)
        let exampleData = ExampleData().getData(key: "Grade 1.Playing.\(exName)")
        var recordedIndex = 0
        var adjust:Double?
        print("\n=== Correct === \(self.fileName)")
        var correctCtr = 0
        for correctNote in correctNotes {
            if recordedIndex >= noteOffsets.count {
                print("=============== Too few notes")
                break
            }
            
            let recordedNote = noteOffsets[recordedIndex]
            //adjust tempo based on first note recorded
            if recordedIndex == 0 {
                let segs = Double(recordedNote.durationSegments())
                adjust = segs / correctNote.getValue()
            }
            
            let diff = Double(recordedNote.durationSegments()) - correctNote.getValue()
            let adjDiff = diff / adjust!
            
            let percentDiff = abs(adjDiff - correctNote.getValue()) / correctNote.getValue() * 100.0
            let ok = percentDiff < 15.0
            print("  ctr:", correctCtr, "correctValue:", correctNote.getValue(),
                  "\t\trecordedValue:", str(adjDiff), "\t:\(str(percentDiff))%", "\t\tOK:", ok)
            recordedIndex += 1
            correctCtr += 1
        }
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
    
    func publishFFT(offset:Int, windowSizePercent:Double) {
        //Fourier
        self.fourierTransformOutputPublished = []
        var ctr = 0
        for f in self.fourierTransformOutput {
            self.fourierTransformOutputPublished.append(ValWithTag(xValue:ctr, val:f, pointType: PointType.correctNoteActual))
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
