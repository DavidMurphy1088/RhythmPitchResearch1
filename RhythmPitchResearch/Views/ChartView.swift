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

    func getColor(_ pointType:PointType) -> Color {
        if pointType == PointType.segment {
            return .blue
        }
        if pointType == PointType.noteOffset {
            return .red
        }
        if pointType == PointType.correctNoteActual {
            return .purple
        }
        if pointType == PointType.correctNoteSynched {
            return .green
        }
        if pointType == PointType.error {
            return .orange
        }
        return .black
    }
    
    func getPointTypeOrigin(marker:ValWithTag, geo:GeometryProxy) -> CGPoint {
        if marker.pointType == PointType.correctNoteActual {
            return CGPoint(x: geo.size.width * 0.66, y: geo.size.height)
        }
        if marker.pointType == PointType.correctNoteSynched {
            return CGPoint(x: geo.size.width * 0.50, y: geo.size.height)
        }
        return CGPoint(x: geo.size.width/2.0, y: 0.0)
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
                            .stroke(getColor(point.pointType), lineWidth: 2)
                        }
                        
                        // Markers
                        ForEach(self.markers, id: \.self) { marker in
                            Path { path in
                                let x = Double(marker.xValue - minX) * xScale
                                path.move   (to: CGPoint(x: x, y: geometry.size.height / 2.0))
                                path.addLine(to: getPointTypeOrigin(marker: marker, geo: geometry))
                            }
                            .stroke(getColor(marker.pointType), lineWidth: 2)
                        }

                        // X axis ticks
                        
                        let numXTicks = 20
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
                                .rotationEffect(Angle(degrees: -90))
                                .position(x: CGFloat(x), y: geometry.size.height / 2.0 + 30)
                                
                        }
                    }
                    
                }
            }
        }
        
    }
    
}
