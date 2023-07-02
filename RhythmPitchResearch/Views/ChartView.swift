import SwiftUI
import CoreData
import AVFoundation
import Accelerate

struct ChartView: View {
    let dataPoints: [ValWithTag]
    let markers: [ValWithTag]
    let offset:Double
    var title:String
    let totalPoints:Int

    init(dataPoints:[ValWithTag], markers:[ValWithTag], offset:Double, title:String) { //, segmentOffset:Int) {
        self.dataPoints = dataPoints
        self.markers = markers
        self.offset = offset
        self.title = title
        totalPoints = self.dataPoints.count
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
        
    func minMaxX() -> (Int, Int) {
        var max = 0
        var min = Int.max
        for p in self.dataPoints {
            if p.xValue > max {
                max = p.xValue
            }
            if p.xValue < min {
                min = p.xValue
            }
        }
        return (min, max)
    }
    
    func minMaxY() -> (Double, Double) {
        var max = 0.0
        var min = Double.infinity
        for p in self.dataPoints {
            if abs(p.val) > max {
                max = abs(p.val)
            }
            if abs(p.val) < min {
                min = abs(p.val)
            }
        }
        return (min, max)
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

    var body: some View {
        VStack {
            if dataPoints.count > 0 {
                HStack {
                    //let max = 0 //dataPoints.max()
                    Text("\(self.title)  - points:\(dataPoints.count)  max:\(self.minMaxY().1)      markerCount:\(markers.count)").padding()
                }


                GeometryReader { geometry in
                    ZStack {
                        let (minX, maxX) = self.minMaxX()
                        let xRange:Int = maxX - minX
                        let xScale = geometry.size.width / Double(xRange)
                        let yScale = geometry.size.height / (self.minMaxY().1 * 2.0)
                        
                        ForEach(self.dataPoints, id: \.self) { point in
                            Path { path in
                                let x = Double(point.xValue - minX) * xScale
                                let y = point.val * yScale
                                path.move   (to: CGPoint(x: x, y: geometry.size.height / 2.0 - y))
                                path.addLine(to: CGPoint(x: x, y: geometry.size.height / 2.0))
                            }
                            .stroke(getColor(point.tag), lineWidth: 2)
                        }
                        
                        // Markers
                        ForEach(self.markers, id: \.self) { marker in
                            Path { path in
                                let x = Double(marker.xValue - minX) * xScale
                                path.move   (to: CGPoint(x: x, y: geometry.size.height / 2.0))
                                path.addLine(to: CGPoint(x: geometry.size.width / 2.0, y: 0.0))
                            }
                            .stroke(getColor(marker.tag), lineWidth: 2)
                        }


                        // X axis ticks
                        
                        let numXTicks = 10
                        let tickLen = geometry.size.width / Double(numXTicks)
                        let tickRange:Int = Int(Double(xRange) / Double(numXTicks))
                        
                        ForEach(Array(0..<numXTicks), id: \.self) { idx in
                            let x = Double(idx) * tickLen
                            let y = 5.0
                            Path { path in
                                path.move   (to: CGPoint(x: x, y: geometry.size.height / 2.0 - y))
                                path.addLine(to: CGPoint(x: x, y: geometry.size.height / 2.0))
                            }
                            .stroke(.black, lineWidth: 2)
                            let xName = minX + (tickRange * idx)
                            Text("\(xName)")
                                .position(x: CGFloat(x), y: geometry.size.height / 2.0 + 10)
                        }
                    }
                    
                }
            }
        }
        
    }
    
}
