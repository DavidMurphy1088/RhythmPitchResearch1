import SwiftUI
import CoreData
import Foundation

struct ContentView: View {
    @ObservedObject var audio = Audio()
    let name = "Example 3_SkyPad" //GABCBAG_Sine"
    @State var offset:Double = 0.0 //8000.0
    @State var windowSizePercent:Double = 33.0

    func getOffset() -> Int {
        return (Int(self.offset) / 1000) * 1000
    }
    
    var body: some View {
        VStack {
            Text("Test")
            HStack {
                Button(action: {
                    //                    audio.readFile(name: name)
                    //                    audio.segmentFile(name:name)
                    //                    audio.getNoteOnsets(name: name)
                    audio.analyse(name: name)
                    //audio.publish(offset: Int(offset), windowSize: windowSize)
                }) {
                    Text("analyse Audio File")
                }
                Button(action: {
                    audio.publish(offset: Int(offset), windowSizePercent: windowSizePercent)
                }) {
                    Text("Publish Audio")
                }

                Button(action: {
                    audio.performFourierTransform(inArray: audio.audioBufferFrames, publish: true)
                }) {
                    Text("Fourier")
                }
                
                Button(action: {
                    audio.publishFFT(offset: Int(offset), windowSizePercent: windowSizePercent)
                }) {
                    Text("Publish FFT")
                }

                Button(action: {
                    audio.analyseAll()
                }) {
                    Text("Analyse ALL")
                }
                

            }
            
            HStack {
                Text("Offset:\(String(format: "%.0f", self.offset))").padding()
                Slider(value: self.$offset, in: 0.0...25000.0).padding()
                Text("Window:\(String(format: "%.0f", self.windowSizePercent))%").padding()
                Slider(value: self.$windowSizePercent, in: 0.2...100.0).padding()
            }
            
            .padding()
            
            if true {
                ChartView(dataPoints: audio.segmentAveragesPublished,
                          markers: audio.markersPublished,
                          offset: offset,
                          title: "Sample Averages"
                          //segmentOffset: getOffset()
                )
                .border(Color.indigo)
                .padding(.horizontal)
            }
//            ChartView(dataPoints: audio.fourierTransformOutputPublished,
//                      markers: audio.noteStartSegmentsPublished,
//                      title: "Fourier"
//                      //segmentOffset: getOffset()
//            )
//            .border(Color.indigo)
//            .padding(.horizontal)

        }
//        .onAppear() {
//            for i in 0..<100 {
//                let s = sin(Double(i)) * 10.0
//                dataPoints.append(Float(s))
//            }
//        }
    }
        
}

