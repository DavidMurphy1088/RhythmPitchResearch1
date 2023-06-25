import Foundation
import SwiftUI

enum AccidentalType {
    case sharp
    case flat
}

enum HandType {
    case left
    case right
}

enum QuaverBeamType {
    case none
    case start
    case middle
    case end
}

enum NoteTag {
    case noTag
    case inError
    case renderedInError //e.g. all rhythm after a rhythm error is moot
    case hilightExpected //hilight the correct note that was expected
}

class Note : Hashable, Comparable, ObservableObject {
    @Published var hilite = false
    @Published var noteTag:NoteTag = .noTag
    static let MIDDLE_C = 60 //Midi pitch for C4
    static let OCTAVE = 12
    static let noteNames:[Character] = ["A", "B", "C", "D", "E", "F", "G"]
    
    static let VALUE_QUAVER = 0.5
    static let VALUE_QUARTER = 1.0
    static let VALUE_HALF = 2.0
    static let VALUE_WHOLE = 4.0

    let id = UUID()
    
    var midiNumber:Int
    var staffNum:Int? //Narrow the display of the note to just one staff
    
    private var value:Double = Note.VALUE_QUARTER
    var isDotted:Bool = false
    var isOnlyRhythmNote = false

    var sequence:Int = 0 //the note's sequence position
    var rotated:Bool = false //true if note must be displaued vertically rotated due to closeness to a neighbor.
    var beamType:QuaverBeamType = .none
    //the note where the quaver beam for this note ends
    var beamEndNote:Note? = nil
    
    static func == (lhs: Note, rhs: Note) -> Bool {
        //return lhs.midiNumber == rhs.midiNumber
        return lhs.id == rhs.id
    }
    static func < (lhs: Note, rhs: Note) -> Bool {
        return lhs.midiNumber < rhs.midiNumber
    }
    
    static func isSameNote(note1:Int, note2:Int) -> Bool {
        return (note1 % 12) == (note2 % 12)
    }
    
    init(num:Int, value:Double = Note.VALUE_QUARTER, staffNum:Int? = nil, isDotted:Bool = false) {
        self.midiNumber = num
        self.staffNum = staffNum
        self.value = value
        self.isDotted = isDotted
        if value == 3.0 {
            self.isDotted = true
        }
    }
    
    func getValue() -> Double {
        return self.value
    }
    
    func setValue(value:Double) {
        self.value = value
        if value == 3.0 {
            self.isDotted = true
        }
    }
    
    func setNoteTag(_ tag: NoteTag) {
        DispatchQueue.main.async {
            self.noteTag = tag
        }
    }

    func setHilite(hilite: Bool) {
        DispatchQueue.main.async {
            self.hilite = hilite
        }
    }
    
    func getNoteValueName() -> String {
        var name = self.isDotted ? "dotted " : ""
        switch self.value {
        case 0.50 :
            name += "quaver"
        case 1.0 :
            name += "crotchet"
        case 2.0 :
            name += "minim"
        case 3.0 :
            name += "minim"
        default :
            name += "semibreve"
        }
        return name
    }
    
    func setIsOnlyRhythm(way: Bool) {
        self.isOnlyRhythmNote = way
        if self.isOnlyRhythmNote {
            self.midiNumber = Note.MIDDLE_C + Note.OCTAVE - 1
        }
        
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(midiNumber)
    }
    
    static func staffNoteName(idx:Int) -> Character {
        if idx >= 0 {
            return self.noteNames[idx % noteNames.count]
        }
        else {
            return self.noteNames[noteNames.count - (abs(idx) % noteNames.count)]
        }
    }

    static func getAllOctaves(note:Int) -> [Int] {
        var notes:[Int] = []
        for n in 0...88 {
            if note >= n {
                if (note - n) % 12 == 0 {
                    notes.append(n)
                }
            }
            else {
                if (n - note) % 12 == 0 {
                    notes.append(n)
                }
            }
        }
        return notes
    }
    
    static func getClosestOctave(note:Int, toPitch:Int, onlyHigher: Bool = false) -> Int {
        let pitches = Note.getAllOctaves(note: note)
        var closest:Int = note
        var minDist:Int?
        for p in pitches {
            if onlyHigher {
                if p < toPitch {
                    continue
                }
            }
            let dist = abs(p - toPitch)
            if minDist == nil || dist < minDist! {
                minDist = dist
                closest = p
            }
        }
        return closest
    }



}
