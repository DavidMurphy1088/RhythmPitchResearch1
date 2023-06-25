import SwiftUI
import CoreData
import AVFoundation
import Accelerate

struct ChartView: View {
    let dataPoints: [ValWithTag]
    let markers: [ValWithTag]
    //let segmentOffset:Int
    var title:String
    let totalPoints:Int

    init(dataPoints:[ValWithTag], markers:[ValWithTag], title:String) { //, segmentOffset:Int) {
        self.dataPoints = dataPoints
        self.markers = markers
        self.title = title
        //self.segmentOffset = segmentOffset
        totalPoints = self.dataPoints.count
    }
    
    func numPoints() -> Int {
        //return windowSize < 100 ? 100 : Int(windowSize)
        return dataPoints.count
    }
    
    func getMax(_ array:[Float]) -> Float? {
        return Float(array.max() ?? 0.0)
    }
     
    func maxy() -> Double {
        var max:Double = 0.0
        for p in dataPoints {
            if p.val > max {
                max = p.val
            }
        }
        return max * 2.0
    }
    
    func getColor(_ tag:Int) -> Color {
        if tag == 0 {
            return .blue
        }
        if tag == 1 {
            return .red
        }
        if tag == 2 {
            return .green
        }
        return .black
    }
    
    func getMax() -> Double {
        var max = 0.0
        for p in self.dataPoints {
            if p.val > max {
                max = p.val
            }
        }
        return max
    }
    
    var body: some View {
        VStack {
            //let l = log()
            if dataPoints.count > 0 {
                HStack {
                    //let max = 0 //dataPoints.max()
                    Text("\(self.title) points:\(dataPoints.count) max:\(getMax()) markerCount:\(markers.count)").padding()
                }
                GeometryReader { geometry in
                    ZStack {
                        let xScale = geometry.size.width / CGFloat(numPoints())
                        let yScale = geometry.size.height / CGFloat(maxy())
                        
                        ForEach(Array(0..<totalPoints), id: \.self) { index in
                            Path { path in
                                if index < dataPoints.count {
                                    let x = CGFloat(Double(index)) * xScale
                                    let y = geometry.size.height / 2.0 - CGFloat(dataPoints[index].val) * yScale
                                    if dataPoints[index].tag == 0 {
                                        path.move(to: CGPoint(x: x, y: geometry.size.height / 2.0))
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                    else {
                                        path.move(to: CGPoint(x: x, y: geometry.size.height / 2.0))
                                        path.addLine(to: CGPoint(x: 0, y: 0))
                                    }
                                }
                            }
                            .stroke(getColor(dataPoints[index].tag), lineWidth: 2) // Customize the line appearance
                        }
                        
                        // X - axis

                        ForEach(Array(0..<totalPoints), id: \.self) { index in
                        //ForEach(0..<totalPoints) { index in
                            if index < dataPoints.count {
                                //let show:Bool = dataPoints.count < 2000 ? (index % 100 == 0) : (index % 1000 == 0)
                                let show = dataPoints[index].idx % 1000 == 0
                                if show {
                                    let x = CGFloat(Double(index)) * xScale
                                    let y = geometry.size.height / 2.0 - CGFloat(dataPoints[index].val) * yScale
                                    //let point =
                                    Text("\(dataPoints[index].idx)")
                                        .position(x: CGFloat(index) * xScale, y: geometry.size.height * 0.47)
                                    //path.move(to: CGPoint(x: x, y: geometry.size.height / 2.0))
                                    //path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                    }

            }
            }
        }
//        .onAppear() {
//            self.windowSize1 = Double(self.dataPoints.count)
//        }
    }
    
}
