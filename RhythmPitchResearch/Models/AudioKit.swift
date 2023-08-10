//import Foundation
//import AudioKit
//import AudioKit
////import AudioKitEX
////import AudioKitUI
//import AudioToolbox
//
//class AudioKit {
//    func test() {
//        guard let file = try? AKAudioFile(readFileName: "yourFileName.m4a"),
//              let player = try? AKPlayer(audioFile: file) else {
//            fatalError("Could not load or play the audio file.")
//        }
//        
//        
//        
//        
//        let name = "iPhone_Three_Octaves"
//        let ext = "m4a"
//        let noteAnalyzer = NoteOnsetAnalyser()
//        //let name = "C_Octave_To_C_Piano_And_Down" //C_Octave_To_C_Piano"
//
//        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
//            print("Error :: File  not found in the app bundle.")
//            return
//        }
// 
//        let engine = AudioEngine()
//        let player = AudioPlayer(url: url)
//        //player.file =
//        //player?.play()
//        
//        let pitchTap = PitchTap(player) { pitches, amplitudes in
//            for (index, pitch) in pitches.enumerated() {
//                print("Pitch \(index): \(pitch) Hz, Amplitude: \(amplitudes[index])")
//            }
//        }
//        
//    }
//}
