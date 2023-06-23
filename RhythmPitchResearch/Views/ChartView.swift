import SwiftUI
import CoreData
import AVFoundation
import Accelerate

struct ChartView: View {
    let dataPoints: [Float]
    let markers: [ValWithTag]
    let segmentOffset:Int
    var title:String
    let totalPoints:Int

    init(dataPoints:[Float], markers:[ValWithTag], title:String, segmentOffset:Int) {
        self.dataPoints = dataPoints
        self.markers = markers
        self.title = title
        self.segmentOffset = segmentOffset
        totalPoints = self.dataPoints.count
    }
    
    func numPoints() -> Int {
        //return windowSize < 100 ? 100 : Int(windowSize)
        return dataPoints.count
    }
    
    func getMax(_ array:[Float]) -> Float? {
        return Float(array.max() ?? 0.0)
    }
    
    var body: some View {
        VStack {
            //let l = log()
            if dataPoints.count > 0 {
                HStack {
                    let max = 0 //dataPoints.max()
                    Text("\(self.title) points:\(dataPoints.count) markerCount:\(markers.count)").padding()
                }
                GeometryReader { geometry in
                    ZStack {
                        let xScale = geometry.size.width / CGFloat(numPoints())
                        let yScale = geometry.size.height / (CGFloat(getMax(dataPoints) ?? 10) / 0.5)
                        
                        Path { path in
                            //path.move(to: CGPoint(x: 0, y: geometry.size.height - CGFloat(dataPoints[Int(offset)]) * yScale))
                            //path.move(to: CGPoint(x: 0, y: 0))
                            var ctr = 0
                            for index in Int(0)..<totalPoints {
                                if index < dataPoints.count {
                                    let x = CGFloat(Double(index)) * xScale
                                    let y = geometry.size.height / 2.0 - CGFloat(dataPoints[index]) * yScale
                                    //let point =
                                    path.move(to: CGPoint(x: x, y: geometry.size.height / 2.0))
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color.blue, lineWidth: 2) // Customize the line appearance
                        
                        // X - axis
                        ForEach(0..<totalPoints) { dp in
                            let showxx:Bool = dataPoints.count < 2000 ? (dp % 100 == 0) : (dp % 1000 == 0)
                            //if showX(count: dataPoints.count) {
                            if showxx {
                                Text("\(dp + segmentOffset)")
                                    .position(x: CGFloat(dp) * xScale, y: geometry.size.height * 0.5)
                            }
                        }
                        
                        // Markers
                        
                        Path { path in
                            for i in Int(0)..<Int(markers.count) {
                                if markers[i].tag == 0 {
                                    path.move(to: CGPoint(x: 0, y: 0))
                                    let x = CGFloat(Double(markers[i].idx - segmentOffset)) * xScale
                                    let y = geometry.size.height / 2.0
                                    let point = CGPoint(x: x, y:y)
                                    path.addLine(to: point)
                                }
                            }
                        }
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        
                        Path { path in
                            for i in Int(0)..<Int(markers.count) {
                                if markers[i].tag == 1 {
                                    path.move(to: CGPoint(x: 0, y: 0))
                                    let x = CGFloat(Double(markers[i].idx - segmentOffset)) * xScale
                                    let y = geometry.size.height / 2.0
                                    let point = CGPoint(x: x, y:y)
                                    path.addLine(to: point)
                                }
                            }
                        }
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    }
//                    .gesture(
//                        DragGesture()
//                            .onChanged { gesture in
//                                let translation = gesture.translation
//
//                                if abs(translation.width) > abs(translation.height) {
//                                    //swipeDirection = translation.width > 0 ? .right : .left
//                                    let m = translation.width > 0 ? 1.1 : 0.9
//                                    //if swipeDirection == .left {
//                                    //print("Swipe", m, self.offset)
//                                        self.offset *= m
//                                    //}
//                                } else {
//                                    //swipeDirection = translation.height > 0 ? .down : .up
//                                }
//                            }
//                            .onEnded { _ in
//                                //swipeDirection = .none
//                            }
//                    )
            }
            }
        }
//        .onAppear() {
//            self.windowSize1 = Double(self.dataPoints.count)
//        }
    }
    
}
