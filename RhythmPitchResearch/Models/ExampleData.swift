
import Foundation

class ExampleData {
    static var shared = ExampleData()
    var data = [String: String]()
    
    init() {
        
        // =========== Instructions

        data["Grade 1.Intervals Visual.Instructions"] = "In the exam you will be shown three notes, and be asked to identify the intervals as either a second or a third."
        data["Grade 1.Intervals Visual.Hints"] = "Hints - Good luck!"
        
        var instr = "In the exam you will be asked to clap a written 4-bar rhythm in 3/4 time or 4/4 time."
        instr += "\n\nThe note values that could be included are:"
        instr += "\n\n\u{2022} Pair of Quavers/ Eighth Notes (picture)"
        instr += "\n\u{2022} Crotchet / Quarter Note (picture)"
        instr += "\n\u{2022} Minim / Half Note (picture)"
        instr += "\n\u{2022} Dotted Minim / 3/4 Note (picture)"
        instr += "\n\u{2022} Semibreve / Whole Note (picture)"
        
        data["Grade 1.Clapping.Instructions"] = instr
        data["Grade 1.Clapping.Hints"] = "Hints - Good luck!"

        data["Grade 1.Playing.Instructions"] = "In the exam you will be given around 30 seconds to look at a melody in either the key of C Major or G Major. During this time you may play through the piece. Use your right hand to play the melody, and your left hand to play the tonic chord with the last note."
        data["Grade 1.Playing.Hints"] = "Hints - Good luck!"

        data["Grade 1.Intervals Aural.Instructions"] = "In the exam, the examiner will play two notes, first separately and then together. You will be expected to answer whether the interval is a second or a third."
        data["Grade 1.Intervals Aural.Hints"] = "Hints - Good luck!"

        data["Grade 1.Echo Clap.Instructions"] = "In the exam, the examiner will clap a four-bar rhythm in 2/4 time or 3/4 time. You will be expected to clap the rhythm pattern back to the examiner. A second attempt will be allowed if necessary."
        data["Grade 1.Echo Clap.Hints"] = "Hints - Good luck!"

        // =========== Examples
        
        data["Grade 1.Intervals Visual.Example 1"] = "(TS,3,4) (72,1) (74,2)"
        data["Grade 1.Intervals Visual.Example 2"] = "(TS,4,4) (74,2) (71,2)"
        data["Grade 1.Intervals Visual.Example 3"] = "(TS,3,4) (69,1) (67,2)"
        data["Grade 1.Intervals Visual.Example 4"] = "(TS,2,4) (67,1) (64,1)"
        data["Grade 1.Intervals Visual.Example 5"] = "(TS,3,4) (69,1) (72,2)"
        data["Grade 1.Intervals Visual.Example 6"] = "(TS,C) (69,2) (72,2)"

        data["Grade 1.Playing.Example 1"] = "(TS,4,4) (64,1) (62,1) (60,.5) (62,.5) (64,1) (B) (67,2) (67,2) (B) (65,1) (67,1) (64,1) (62,1) (B) (60,4) "
        data["Grade 1.Playing.Example 2"] = "(TS,3,4) (67,1) (65,1) (64,1) (B) (65,1) (64,1) (62,.5) (60,.5) (B) (64,2) (67,1) (B) (60,3) "
        data["Grade 1.Playing.Example 3"] = "(K) (TS,3,4) (67,1) (69,1) (71,1) (B) (72,1) (71,1) (69,1) (B) (71,2) (69,1) (B) (67,3) "
        data["Grade 1.Playing.Example 4"] = "(K) (TS,4,4) (71,1) (67,.5) (69,.5) (71,1) (72,1) (B) (74,1) (72,1) (71,1) (69,1) (B) (71,2) (72,1) (69,1) (B) (67,4)"
        data["Grade 1.Playing.Example 5"] = "(K) (TS,3,4) (67,1) (69,1) (71,1) (B) (74,2) (71,1) (B) (72,.5) (74,.5) (71,1) (69,1) (B) (67,3)"
        data["Grade 1.Playing.Example 6"] = "(TS,4,4) (67,1) (65,1) (64,1) (62,1) (B) (60,1) (64,1) (65,1) (67,1) (B) (65,2) (62,2) (B) (60,4)"
        data["Grade 1.Playing.Example 7"] = "(TS,4,4) (72,2) (72,2) (B) (76,1) (74,1) (72,2) (B) (74,.5) (76,.5) (79,2) (76,1) (B) (72,4)"
        data["Grade 1.Playing.Example 8"] = "(K) (TS,3,4) (67,1) (69,1) (71,1) (B) (72,1) (74,2) (B) (71,2) (69,1) (B) (67,3)"
        data["Grade 1.Playing.Example 9"] = "(K) (TS,4,4) (67,1) (71,1) (74,2) (B) (72,2) (71,2) (B) (72,1) (74,.5) (72,.5) (71,1) (69,1) (B) (67,4)"
        data["Grade 1.Playing.Example 10"] = "(TS,4,4) (79,1) (76,1) (72,2) (B) (74,2) (76,2) (B) (77,1) (79,2) (76,1) (B) (72,4)"
        
        //data["Grade 1.Playing.Example 7"] = "(K) (TS,3,4) () () () () () () () () () () () () () () () () () () () () () () () () ()"

        data["Grade 1.Clapping.Example 1"] = data["Grade 1.Playing.Example 1"]
        data["Grade 1.Clapping.Example 2"] = data["Grade 1.Playing.Example 2"]
        data["Grade 1.Clapping.Example 3"] = data["Grade 1.Playing.Example 3"]
        data["Grade 1.Clapping.Example 4"] = data["Grade 1.Playing.Example 4"]
        data["Grade 1.Clapping.Example 5"] = data["Grade 1.Playing.Example 5"]
        data["Grade 1.Clapping.Example 6"] = data["Grade 1.Playing.Example 6"]
        data["Grade 1.Clapping.Example 7"] = data["Grade 1.Playing.Example 7"]
        data["Grade 1.Clapping.Example 8"] = data["Grade 1.Playing.Example 8"]
        data["Grade 1.Clapping.Example 9"] = data["Grade 1.Playing.Example 9"]
        data["Grade 1.Clapping.Example 10"] = data["Grade 1.Playing.Example 10"]

        data["Grade 1.Intervals Aural.Example 1"] = "(72,1) (74,1)"
        data["Grade 1.Intervals Aural.Example 2"] = "(74,1) (76,1)"
        data["Grade 1.Intervals Aural.Example 3"] = "(72,1) (76,1)"
        data["Grade 1.Intervals Aural.Example 4"] = "(65,1) (69,1)"

        data["Grade 1.Echo Clap.Example 1"] = "(TS,3,4) (71,2) (71,1) (B) (71,1) (71,1) (71,1) (B) (71,2) (71,1) (B) (71,3))"
        data["Grade 1.Echo Clap.Example 2"] = "(TS,3,4) (71,1) (71,.5) (71,.5) (71,1) (B) (71,2) (71,1) (B) (71,1) (71,.5) (71,.5) (71,1) (B) (71,3)"
        data["Grade 1.Echo Clap.Example 3"] = "(TS,3,4) (71,1) (71,1) (71,1) (B) (71,3) (B) (71,1) (71,1) (71,1) (B) (71,2) (71,1)"
        data["Grade 1.Echo Clap.Example 4"] = "(TS,3,4) (71,1) (71,.5) (71,.5) (71,.5) (71,.5) (B) (71,1) (71,1) (71,1) (B) (71,2) (71,1) (B) (71,3)"
        data["Grade 1.Echo Clap.Example 5"] = "(TS,3,4) (71,1) (71,2) (B) (71,1) (71,2) (B) (71,1) (71,1) (71,1) (B) (71,3)"
        
        data["Grade 1.Echo Clap.Example 6"] = "(TS,2,4) (71,1) (71,.5) (71,.5) (B) (71,1) (71,1) (B) (71,1) (71,.5) (71,.5) (B) (71,2)"
        data["Grade 1.Echo Clap.Example 7"] = "(TS,2,4) (71,.5) (71,.5) (71,.5) (71,.5) (B) (71,1) (71,1) (B) (71,.5) (71,.5) (71,.5) (71,.5) (71,2)"
        data["Grade 1.Echo Clap.Example 8"] = "(TS,2,4) (71,1) (71,1) (B) (71,.5) (71,.5) (71,1) (B) (71,.5) (71,.5) (71,1) (B) (71,2)"
        data["Grade 1.Echo Clap.Example 9"] = "(TS,2,4) (71,.5) (71,.5) (71,1) (B) (71,.5) (71,.5) (71,1) (B) (71,1) (71,1) (B) (71,2)"
        data["Grade 1.Echo Clap.Example 10"] = "(TS,2,4) (71,1) (71,1) (B) (71,.5) (71,.5) (71,.5) (71,.5) (B) (71,1) (71,.5) (71,.5) (B) (71,2)"

        //data["Intervals Visual.test"] = data["Grade 1.Intervals Visual.Example 1"]
        //data["Playing.test"] = data["Grade 1.Playing.Example 1"]
        //data["Clapping.test"] = data["Grade 1.Playing.Example 1"]
        
        data["test_interval"] = data["Grade 1.Intervals Visual.Example 1"]
        data["test_clap"] = "(K) (TS,4,4) (71,1) (B) (67,.5) (69,.5) (71,1) (72,1) (B) (74,1)"
        data["test_aural_interval"] = data["Grade 1.Intervals Visual.Example 1"]
        
        //data["test"]  = "(TS,3,4) (67,1) (65,1) (64,1) (B) (65,1) (64,1) (62,.5) (60,.5) (B) (64,2) (67,1) (B) (60,3) "
        //data["test"]  = "(72,1) (72,.5) (74,.5) (72,1)"
        data["test"]  = "(67,.5) (69,.5) (71,2)"
    }
    
//    func get(contentSection:ContentSection) -> [Any]! {
//        var current = contentSection
//        var key = ""
//        while true {
//            key = current.name + key
//            let par = current.parent
//            if par == nil {
//                break
//            }
//            current = par!
//            key = "." + key
//        }
//        return getData(key: key)
//    }
    
    func getData(key:String, warnNotFound:Bool=true) -> [Any]! {
        //let key = grade+"."+testType+"."+exampleKey
        let data = data[key]
        guard data != nil else {
            if warnNotFound {
                print("No data for \(key)")
            }
            return nil
        }
        //data = data!.replacingOccurrences(of: " ", with: "")
        let tuples = data!.components(separatedBy: " ")

        var result:[Any] = []
        for entry in tuples {
            var tuple = entry.replacingOccurrences(of: "(", with: "")
            tuple = tuple.replacingOccurrences(of: ")", with: "")
            let parts = tuple.components(separatedBy: ",")
            if parts.count == 2  {
                let notePitch:Int? = Int(parts[0])
                if let notePitch = notePitch {
                    let pitch = Int(parts[0])
                    let value = Double(parts[1]) ?? 1
                    if let pitch = pitch {
                        result.append(Note(num: notePitch, value: value))
                    }
                }
                else {
                    if parts[0] == "TS" {
//                        var ts = TimeSignature(top: 4, bottom: 4)
//                        ts.isCommonTime = true
//                        result.append(result.append(ts))
                    }

                }
            }
            else {
                if parts.count == 1 {
                    if parts[0] == "K" {
                        //result.append(KeySignature(type: .sharp, count: 1))
                    }
                    if parts[0] == "B" {
                        //result.append(BarLine())
                    }
                }
                if parts.count == 3 {
                    //result.append(TimeSignature(top: Int(parts[1]) ?? 0, bottom: Int(parts[2]) ?? 0))
                }
            }
        }
        //Logger.logger.log(self, "Entry count for \(key) is \(result.count)")
        return result
    }
}
