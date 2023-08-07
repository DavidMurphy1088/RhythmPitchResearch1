import SwiftUI

struct ContentViewSpectogram: View {
    
    @EnvironmentObject var audioSpectrogram: AudioSpectrogram
    var noteAnalyzer = NoteOnsetAnalyser()
    //@State var audioSpectrogram:AudioSpectrogram = AudioSpectrogram()

    var body: some View {
        
        VStack {
            
            Image(decorative: audioSpectrogram.outputImage,
                  scale: 1,
                  orientation: .left)
            .resizable()
            
                HStack {
                    Button(action: {
                        noteAnalyzer.analyzeFile()
                    }) {
                        Text("Test Read WAV File")
                    }
//                    HStack {
//                        Button(action: {
//                            audioSpectrogram.speed = 2.0
//                        }) {
//                            Text("StartMic")
//                        }
//                        Button(action: {
//                            audioSpectrogram.speed = 1000.0
//                        }) {
//                            Text("StopMic")
//                        }
//                    }
                    Text("SamplesPerFrame \(Int(audioSpectrogram.samplesPerFrame))")
                    Slider(value: $audioSpectrogram.samplesPerFrame,
                           in: 100 ... 4096)
                }
                HStack {
                    
                    Divider().frame(height: 40)
                    
                    Text("Gain \(audioSpectrogram.gain)")
                    Slider(value: $audioSpectrogram.gain,
                           in: 0.01 ... 0.08
                    )
                    
                    Divider().frame(height: 40)
                    
                    Text("Zero Ref \(audioSpectrogram.zeroReference)")
                    Slider(value: $audioSpectrogram.zeroReference,
                           in: 10 ... 2500)
                    
                    Text("Speed \(audioSpectrogram.speed)")
                        .onChange(of: audioSpectrogram.speed) { newValue in
                            print("Speed Change: \(Int(newValue))")
                        }
                    Slider(value: $audioSpectrogram.speed,
                           in: 1.0 ... 3000.0)
                    
                    Picker("Mode", selection: $audioSpectrogram.mode) {
                        ForEach(AudioSpectrogram.Mode.allCases) { mode in
                            Text(mode.rawValue.capitalized)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                
            .padding()
        }
    }
}
