import Foundation
import UIKit
import UIKit.UIGestureRecognizerSubclass
import SwiftSignalKit
import AsyncDisplayKit
import Display
import AppBundle
import LegacyComponents

struct ArbitraryRandomNumberGenerator : RandomNumberGenerator {
    init(seed: Int) { srand48(seed) }
    func next() -> UInt64 { return UInt64(drand48() * Double(UInt64.max)) }
}



func generateMaskImage(size originalSize: CGSize, position: CGPoint, inverse: Bool) -> UIImage? {
    var size = originalSize
    var position = position
    var scale: CGFloat = 1.0
    if max(size.width, size.height) > 640.0 {
        size = size.aspectFitted(CGSize(width: 640.0, height: 640.0))
        scale = size.width / originalSize.width
        position = CGPoint(x: position.x * scale, y: position.y * scale)
    }
    return generateImage(size, rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
                
        
        let startAlpha: CGFloat = inverse ? 0.0 : 1.0
        let endAlpha: CGFloat = inverse ? 1.0 : 0.0
        
        var locations: [CGFloat] = [0.0, 0.7, 0.95, 1.0]
        let colors: [CGColor] = [UIColor(rgb: 0xffffff, alpha: startAlpha).cgColor, UIColor(rgb: 0xffffff, alpha: startAlpha).cgColor, UIColor(rgb: 0xffffff, alpha: endAlpha).cgColor, UIColor(rgb: 0xffffff, alpha: endAlpha).cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        let center = position
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0.0, endCenter: center, endRadius: min(10.0, min(size.width, size.height) * 0.4) * scale, options: .drawsAfterEndLocation)
    })
}

public class InvisibleInkDustNode: ASDisplayNode {
    private var currentParams: (size: CGSize, color: UIColor, textColor: UIColor, rects: [CGRect], wordRects: [CGRect])?
    private var animColor: CGColor?
    private let enableAnimations: Bool
    
    private weak var textNode: TextNode?
    private let textMaskNode: ASDisplayNode
    private let textSpotNode: ASImageNode
    
    private let emitterMaskNode: ASDisplayNode
    private let emitterSpotNode: ASImageNode
    
    private var staticNode: ASImageNode?
    private var staticParams: (size: CGSize, color: UIColor, rects: [CGRect])?
        
    public var isRevealed = false
    private var isExploding = false
    
    private var invisibleInkDustEffectLayer: InvisibleInkDustEffectLayer?
    
    public init(textNode: TextNode?, enableAnimations: Bool) {
        self.textNode = textNode
        self.enableAnimations = enableAnimations
        
        self.textMaskNode = ASDisplayNode()
        self.textMaskNode.isUserInteractionEnabled = false
        self.textSpotNode = ASImageNode()
        self.textSpotNode.contentMode = .scaleToFill
        self.textSpotNode.isUserInteractionEnabled = false
        
        self.emitterMaskNode = ASDisplayNode()
        self.emitterSpotNode = ASImageNode()
        self.emitterSpotNode.contentMode = .scaleToFill
        self.emitterSpotNode.isUserInteractionEnabled = false
        
        let invisibleInkDustEffectLayer = InvisibleInkDustEffectLayer()
        self.invisibleInkDustEffectLayer = invisibleInkDustEffectLayer
        invisibleInkDustEffectLayer.zPosition = 10.0
        invisibleInkDustEffectLayer.transform = CATransform3DMakeRotation(CGFloat(Double.pi), 0.0, 0.0, 1.0)

        super.init()
        
        self.textMaskNode.addSubnode(self.textSpotNode)
        self.emitterMaskNode.addSubnode(self.emitterSpotNode)
        
        self.view.layer.addSublayer(invisibleInkDustEffectLayer)
    }
    
    public override func didLoad() {
        super.didLoad()
        
        if self.enableAnimations {
            
        } else {
            let staticNode = ASImageNode()
            self.staticNode = staticNode
            self.addSubnode(staticNode)
        }
        
        self.updateEmitter()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tap(_:))))
    }
    
    public func update(revealed: Bool, animated: Bool = true) {
        guard self.isRevealed != revealed, let textNode = self.textNode else {
            return
        }
        
        self.isRevealed = revealed
        
        if revealed {
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.3, curve: .linear) : .immediate
            transition.updateAlpha(node: self, alpha: 0.0)
            transition.updateAlpha(node: textNode, alpha: 1.0)
        } else {
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.4, curve: .linear) : .immediate
            transition.updateAlpha(node: self, alpha: 1.0)
            transition.updateAlpha(node: textNode, alpha: 0.0)
            
            if self.isExploding {
                self.isExploding = false
//                self.emitterLayer?.setValue(false, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
            }
        }
    }
    
    public func revealAtLocation(_ location: CGPoint) {
        guard let (_, _, textColor, _, _) = self.currentParams, let textNode = self.textNode, !self.isRevealed else {
            return
        }
        
        print(textColor)
        
        self.isRevealed = true
        
        if self.enableAnimations {
            self.isExploding = true
            
            Queue.mainQueue().after(0.1 * UIView.animationDurationFactor()) {
                textNode.alpha = 1.0
                
                textNode.view.mask = self.textMaskNode.view
                self.textSpotNode.frame = CGRect(x: 0.0, y: 0.0, width: self.emitterMaskNode.frame.width * 3.0, height: self.emitterMaskNode.frame.height * 3.0)
                
            }
            
            Queue.mainQueue().after(0.8 * UIView.animationDurationFactor()) {
                self.isExploding = false
                self.textSpotNode.layer.removeAllAnimations()
                
                self.emitterSpotNode.layer.removeAllAnimations()
            }
        } else {
            textNode.alpha = 1.0
            textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
            
            self.staticNode?.alpha = 0.0
            self.staticNode?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
        }
    }
    
    @objc private func tap(_ gestureRecognizer: UITapGestureRecognizer) {
        let location = gestureRecognizer.location(in: self.view)
        self.revealAtLocation(location)
    }
    
    private func updateEmitter() {
        guard let (size, color, _, lineRects, wordRects) = self.currentParams else {
            return
        }
        
        if self.enableAnimations {
            
            
//            let radius = max(size.width, size.height)
           
            
            var square: Float = 0.0
            for rect in wordRects {
                square += Float(rect.width * rect.height)
            }
            

        } else {
            if let staticParams = self.staticParams, staticParams.size == size && staticParams.color == color && staticParams.rects == lineRects && self.staticNode?.image != nil {
                return
            }
            self.staticParams = (size, color, lineRects)

            var combinedRect: CGRect?
            var combinedRects: [CGRect] = []
            for rect in lineRects {
                if let currentRect = combinedRect {
                    if abs(currentRect.minY - rect.minY) < 1.0 && abs(currentRect.maxY - rect.maxY) < 1.0 {
                        combinedRect = currentRect.union(rect)
                    } else {
                        combinedRects.append(currentRect.insetBy(dx: 0.0, dy: -1.0 + UIScreenPixel))
                        combinedRect = rect
                    }
                } else {
                    combinedRect = rect
                }
            }
            if let combinedRect {
                combinedRects.append(combinedRect.insetBy(dx: 0.0, dy: -1.0))
            }
            
            Queue.concurrentDefaultQueue().async {
                var generator = ArbitraryRandomNumberGenerator(seed: 1)
                let image = generateImage(size, rotatedContext: { size, context in
                    let bounds = CGRect(origin: .zero, size: size)
                    context.clear(bounds)
                    
                    context.setFillColor(color.cgColor)
                    for rect in combinedRects {
                        if rect.width > 10.0 {
                            let rate = Int(rect.width * rect.height * 0.25)
                            for _ in 0 ..< rate {
                                let location = CGPoint(x: .random(in: rect.minX ..< rect.maxX, using: &generator), y: .random(in: rect.minY ..< rect.maxY, using: &generator))
                                context.fillEllipse(in: CGRect(origin: location, size: CGSize(width: 1.0, height: 1.0)))
                            }
                        }
                    }
                })
                Queue.mainQueue().async {
                    self.staticNode?.image = image
                }
            }
            self.staticNode?.frame = CGRect(origin: CGPoint(), size: size)
        }
    }
    
    public func update(size: CGSize, color: UIColor, textColor: UIColor, rects: [CGRect], wordRects: [CGRect]) {
        print("asdasdfsdf5" ,frame.size, size)
        
        self.currentParams = (size, color, textColor, rects, wordRects)
                
        let bounds = CGRect(origin: CGPoint(), size: size)
        self.emitterMaskNode.frame = bounds
        self.textMaskNode.frame = CGRect(origin: CGPoint(x: 3.0, y: 3.0), size: size)
        
        self.staticNode?.frame = bounds
        
        if self.isNodeLoaded {
            self.updateEmitter()
        }
        
        if let textNode = textNode {
            if let image = makeContentSnapshot(node: textNode) {
                let iv = UIImageView(image: image)
                self.view.addSubview(iv)
                
                self.invisibleInkDustEffectLayer?.frame = CGRect(origin: CGPoint(), size: size)
                self.invisibleInkDustEffectLayer?.updateContent(frame: CGRect(origin: CGPoint(), size: size), image: image)
            }
        }
    }
    
    func makeContentSnapshot(node: ASDisplayNode) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(node.view.bounds.size, false, 0.0)
        let context = UIGraphicsGetCurrentContext()!
        
        node.view.layer.render(in: context)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let image else {
            return nil
        }
        
        return image
    }
    
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if let (_, _, _, rects, _) = self.currentParams, !self.isRevealed {
            for rect in rects {
                if rect.contains(point) {
                    return true
                }
            }
            return false
        } else {
            return false
        }
    }
}
