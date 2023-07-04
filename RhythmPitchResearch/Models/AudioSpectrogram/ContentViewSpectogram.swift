import SwiftUI

struct ContentViewSpectogram: View {
    
    @EnvironmentObject var audioSpectrogram: AudioSpectrogram
    //@State var audioSpectrogram:AudioSpectrogram = AudioSpectrogram()

    var body: some View {
        
        VStack {
            
            Image(decorative: audioSpectrogram.outputImage,
                  scale: 1,
                  orientation: .left)
            .resizable()
            
            HStack {
                VStack {
                    Button(action: {
                        audioSpectrogram.readFile()
                    }) {
                        Text("Test Read WAV File")
                    }
                    HStack {
                        Button(action: {
                            audioSpectrogram.speed = 2.0
                        }) {
                            Text("StartMic")
                        }
                        Button(action: {
                            audioSpectrogram.speed = 1000.0
                        }) {
                            Text("StopMic")
                        }
                    }
                    
                    Text("Speed")
                        .onChange(of: audioSpectrogram.speed) { newValue in
                            print("Spee Change: \(Int(newValue))")
                        }
                    Slider(value: $audioSpectrogram.speed,
                           in: 1.0 ... 16.0)
                    
                }
                
                Text("Gain")
                Slider(value: $audioSpectrogram.gain,
                       in: 0.01 ... 0.04)

                Divider().frame(height: 40)
                
                Text("Zero Ref")
                Slider(value: $audioSpectrogram.zeroReference,
                       in: 10 ... 2500)
                
                Divider().frame(height: 40)
                
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
