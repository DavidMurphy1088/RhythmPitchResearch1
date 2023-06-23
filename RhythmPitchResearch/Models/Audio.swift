import SwiftUI
import Foundation
import AVFoundation

class ValWithTag : Hashable {
    var idx:Int
    var val:Float
    var tag:Int
    
    init(_ idx:Int, _ val:Float, _ tag:Int) {
        self.idx = idx
        self.val = val
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
    init(startSegment:Int, endSegment:Int) {
        self.startSegment = startSegment
        self.endSegment = endSegment
    }
    func duration() -> Double {
        return Double(endSegment - startSegment)
    }
}

class Audio : ObservableObject {
    var audioBufferFrames:[Float] = []
    var segmentAverages:[Float] = []
    //@Published var segmentAveragesPublished:[ValWithTag] = []
    @Published var segmentAveragesPublished:[Float] = []

    //var noteStartSegments:[Int] = []
    @Published var noteStartSegmentsPublished:[ValWithTag] = []
    @Published var noteOffsets:[NoteOffset] = []
    
    var milliSecondsPerSegment:Double = 0.0
    let numberFormatter = NumberFormatter()
    var segmentsPerSlice = 1
    
    func str(_ inVal:Double) -> String {
        return String(format: "%.2f", inVal)
    }
    
    func str(_ inVal:Int) -> String {
        numberFormatter.string(from: NSNumber(value: inVal)) ?? ""
    }
    
    func readFile(name:String) {
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
        
        let segmentSize = 10
        let durationSeconds = Double(audioFile.length) / audioFile.fileFormat.sampleRate
        let numSegments = self.audioBufferFrames.count / segmentSize
        self.milliSecondsPerSegment = (durationSeconds * 1000.0) / Double(numSegments)

        self.segmentAverages = []
        
        for segmentIndex in 0..<numSegments {
            var total:Float = 0.0
            let startIndex = segmentIndex * segmentSize
            for s in 0..<segmentSize {
                total += self.audioBufferFrames[startIndex + s]
            }
            let segmentAverage = total / Float(segmentSize)
            self.segmentAverages.append(segmentAverage)
         }

        print("SegmentFile",
              "\n  SegmentSize:", segmentSize,
              "\n  NumSegments:", numSegments,
              "\n  MS Per Segment:", str(milliSecondsPerSegment)
        )
    }
    
    //Find the note onsets by looking for amplitude bumps in slices of the segment averages
    func getNoteOnsets(name:String) {
        let correctNotes = [(64,2), (62,2), (60,1), (62,1), (64,2), (67,4), (67,4), (65,2), (67,2)]
        var lastNoteIdx:Int?
        
        //=============== Parameters ==============
        
        //let segmentsPerSlice = 20
        //self.segmentsPerSlice = 100 // how many segments per slice either side of analysis point
        self.segmentsPerSlice = 200 // how many segments per slice either side of analysis point
        let segmentAdvance = 0.25 // how far to move the analysis point forward each iteration
        let amplitudeChangeThreshold:Float = 0.1 //How amplitude must change
        let lookAheadMS = 50 //How many millisec to lookahead to confirm presence of note (or is amplitude change just a bump)
        let shortestNote = 0.25 //shortest note value, how far to jump ahead after a note onset detected
        //let amplitudeChangeThreshold = maxAmplitude * 0.02
        //let amplitudeChangeThreshold = maxAmplitude * 0.25
        
        let maxAmplitude:Float = self.segmentAverages.max() ?? 0
        let amplitudeChangeThresholdValue = maxAmplitude * amplitudeChangeThreshold
        var segmentIdx = segmentsPerSlice

        self.noteOffsets = []
        //var noteStartSegments:[NoteOffset] = []
        let lookaheadSegments:Int = Int(Double(lookAheadMS) / self.milliSecondsPerSegment)

        while segmentIdx < self.segmentAverages.count {
            let prev = subArray(array: self.segmentAverages, at: segmentIdx, fwd:false, len: segmentsPerSlice)
            let next = subArray(array: self.segmentAverages, at: segmentIdx, fwd:true, len: segmentsPerSlice)
            let prevAvg = prev.reduce(0, +)
            let nextAvg = next.reduce(0, +)
            //let pstd:Float = getStandardDeviation(prev) ?? 1
            //let nstd:Float = getStandardDeviation(next) ?? 1

            //if nstd / pstd > stdChangeThreshold {
            if nextAvg - prevAvg > amplitudeChangeThresholdValue {
                //print("STD prev:", pstd, "next:", nstd, "Ratio:", nstd / pstd)
                let endLookAhead = segmentIdx + lookaheadSegments
                if endLookAhead < self.segmentAverages.count {
                    let lookAhead = subArray(array: self.segmentAverages, at: segmentIdx, fwd:true, len: lookaheadSegments)
                    let lookAheadAvg = lookAhead.reduce(0, +)
                    //let diff = lookAheadAvg - nextAvg
                    //if abs(diff) < 0.25 * nextAvg {
                    if true { //diff > 0 {
                        //save the note location and value
                        if let lastNoteIdx = lastNoteIdx {
                            let lastNoteOffset = NoteOffset(startSegment: lastNoteIdx, endSegment: segmentIdx)
                            noteOffsets.append(lastNoteOffset)
//                            for i in 0...4 * segmentsPerSlice {
//                                self.segmentAverages[segmentIdx + segmentsPerSlice + i] = 0.0
//                            }
                        }
                    }
                }
                lastNoteIdx = segmentIdx
                
                //jump ahead to next note, assume shortest note is value 1/4 of 1.0
                let segmentsPerSec = 1000.0 / Double(self.milliSecondsPerSegment)
                let jumpAhead = max(Int(segmentsPerSec * shortestNote), 1)
                segmentIdx += jumpAhead
            }
            else {
                //TODO What should be amount of segment overlap for ech iteration?
                //segmentIdx += segmentsPerSlice
                segmentIdx += Int(Double(self.segmentsPerSlice) * segmentAdvance)
            }
        }
        if let lastNoteIdx = lastNoteIdx {
            let lastNoteOffset = NoteOffset(startSegment: lastNoteIdx, endSegment: segmentIdx)
            noteOffsets.append(lastNoteOffset)
        }
        
        print("")
        print("segments per Slice", self.segmentsPerSlice, "Amplitude change", amplitudeChangeThreshold)
        print("=== Notes")
        
        for n in 0..<noteOffsets.count {
            let note = noteOffsets[n]
            print(n,
                  "\tStartSeg:", str(note.startSegment),
                  "\tEndSeg:", str(note.endSegment),
                  "\tNumSegments", str(note.endSegment - note.startSegment)
            )
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
    
    func publish(offset:Int, windowSizePercent:Double) {
        DispatchQueue.main.async {
            let startIdx = offset
            let pointsToPublish = Int(Double(self.segmentAverages.count) * windowSizePercent / 100.0)
            print("START published offset:", offset, "window:", windowSizePercent)

            self.segmentAveragesPublished = []
            
            var ctr = 0
            for i in 0..<pointsToPublish {
                let idx = offset + i
                if idx < self.segmentAverages.count {
                    //self.segmentAveragesPublished.append(ValWithTag(i, self.segmentAverages[idx], 1))
                    self.segmentAveragesPublished.append(self.segmentAverages[idx])
                    ctr += 1
                }

             }
            //publish onsets
            var ctrOff = 0
            DispatchQueue.main.async {
                self.noteStartSegmentsPublished = []
                for noteOffset in self.noteOffsets {
                    if noteOffset.startSegment >= startIdx {//&& noteOffset.idx < (noteOffset.idx + pointsToPublish) {
                        self.noteStartSegmentsPublished.append(ValWithTag(noteOffset.startSegment - self.segmentsPerSlice, 0, 1))
                        self.noteStartSegmentsPublished.append(ValWithTag(noteOffset.startSegment, 0, 0))
                        self.noteStartSegmentsPublished.append(ValWithTag(noteOffset.startSegment + self.segmentsPerSlice, 0, 1))

                        ctrOff += 1
                    }
                 }
            }
            print("END  published offset:", offset, "window:", windowSizePercent, "segs:", ctr, "notes:", ctrOff)
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
}
