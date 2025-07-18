//
//  CGPoint+Utility.swift
//  ImageClassification
//
//  Created by Genry on 25.04.2025.
//

import CoreGraphics

extension Array where Element == CGPoint {
    var switchedXY: [CGPoint] {
        map { CGPoint(x: $0.y, y: $0.x) }
    }
    
    var invertedY: [CGPoint] {
        map { CGPoint(x: $0.x, y: 1 - $0.y) }
    }
    
    func inBox(_ box: CGRect) -> [CGPoint] {
        map { point in
            let x = box.minX + point.x * box.width
            let y = box.minY + point.y * box.height
            return CGPoint(x: x, y: y)
        }
    }
    
    func mostRightPoint() -> CGPoint {
        var point = self[0]
        for p in self {
            if point.x < p.x {
                point = p
            }
        }
        return point
    }
    
    func mostLeftPoint() -> CGPoint {
        var point = self[0]
        for p in self {
            if p.x < point.x {
                point = p
            }
        }
        return point
    }
    
    func centerPoint() -> CGPoint {
        var left = self[0]
        var leftIndex = 0
        var leftDirectionPositiveIteration = true
        
        var right = self[0]
        var rightIndex = 0
        var rightDirectionPositiveIteration = true
        
        for (i, p) in self.enumerated() {
            if p.x < left.x {
                left = p
                leftIndex = i
            }
        }
        for (i, p) in self.enumerated() {
            if right.x < p.x {
                right = p
                rightIndex = i
            }
        }
        
        let leftNextPointIndex = leftIndex + 1 == self.count ? 0 : leftIndex + 1
        let leftPreviousPointIndex = leftIndex - 1 < 0 ? self.count - 1 : leftIndex - 1
        leftDirectionPositiveIteration = self[leftNextPointIndex].y  > self[leftPreviousPointIndex].y
        
        let rightNextPointIndex = rightIndex + 1 == self.count ? 0 : rightIndex + 1
        let rightPreviousPointIndex = rightIndex - 1 < 0 ? self.count - 1 : rightIndex - 1
        rightDirectionPositiveIteration = self[rightNextPointIndex].y  > self[rightPreviousPointIndex].y
        
        var centerIndex = 0
        for i in 0..<self.count {
            if leftDirectionPositiveIteration {
                leftIndex = leftIndex + 1 == self.count ? 0 : leftIndex + 1
            } else {
                leftIndex = leftIndex - 1 < 0 ? self.count - 1 : leftIndex - 1
            }
            
            if self[leftIndex] == self[rightIndex] {
                centerIndex = i
                break
            }
            
            if rightDirectionPositiveIteration {
                rightIndex = rightIndex + 1 == self.count ? 0 : rightIndex + 1
            } else {
                rightIndex = rightIndex - 1 < 0 ? self.count - 1 : rightIndex - 1
            }
            
            if self[leftIndex] == self[rightIndex] {
                centerIndex = i
                break
            }
        }
        
        return self[centerIndex]
    }
}
