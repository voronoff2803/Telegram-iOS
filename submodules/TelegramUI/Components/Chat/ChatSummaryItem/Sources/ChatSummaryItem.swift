import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TextFormat
import UrlEscaping
import PhotoResources
import AccountContext
import UniversalMediaPlayer
import TelegramUniversalVideoContent
import WallpaperBackgroundNode
import ChatControllerInteraction
import ChatMessageBubbleContentNode
import ShimmerEffect

private let messageFont = Font.regular(14.0)
private let messageBoldFont = Font.semibold(14.0)
private let messageItalicFont = Font.italic(14.0)
private let messageBoldItalicFont = Font.semiboldItalic(14.0)
private let messageFixedFont = UIFont(name: "Menlo-Regular", size: 13.0) ?? UIFont.systemFont(ofSize: 14.0)

// MARK: AI SummaryChat
public final class ChatSummaryItem: ListViewItem {
    fileprivate let title: String
    fileprivate let text: String
    fileprivate let presentationData: ChatPresentationData
    fileprivate let context: AccountContext
    fileprivate let controllerInteraction: ChatControllerInteraction
    
    public init(title: String, text: String, controllerInteraction: ChatControllerInteraction, presentationData: ChatPresentationData, context: AccountContext) {
        self.title = title
        self.text = text
        self.controllerInteraction = controllerInteraction
        self.presentationData = presentationData
        self.context = context
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        let configure = {
            let node = ChatSummaryItemNode()
            
            let nodeLayout = node.asyncLayout()
            let (layout, apply) = nodeLayout(self, params)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(.None) })
                })
            }
        }
        if Thread.isMainThread {
            async {
                configure()
            }
        } else {
            configure()
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ChatSummaryItemNode {
                let nodeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = nodeLayout(self, params)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation)
                        })
                    }
                }
            }
        }
    }
}

public final class ChatSummaryItemNode: ListViewItemNode {
    public var controllerInteraction: ChatControllerInteraction?
    
    public let offsetContainer: ASDisplayNode
    public let backgroundNode: ASImageNode
    public let titleNode: TextNode
    public let textNode: TextNode
    private var linkHighlightingNode: LinkHighlightingNode?
    
    private var shimmerView: ShimmerEffectForegroundView?
    private var borderView: UIView?
    private var borderMaskView: UIView?
    private var borderShimmerView: ShimmerEffectForegroundView?
    
    private let fetchDisposable = MetaDisposable()
    
    public var currentTextAndEntities: (String, [MessageTextEntity])?
    
    private var theme: ChatPresentationThemeData?
    
    private var wallpaperBackgroundNode: WallpaperBackgroundNode?
    private var backgroundContent: WallpaperBubbleBackgroundNode?
    
    private var absolutePosition: (CGRect, CGSize)?
    
    private var item: ChatSummaryItem?
    
    var gloss: Bool = false {
        didSet {
            guard gloss != oldValue else { return }
            
            self.setupGloss()
        }
    }
    
    public init() {
        self.offsetContainer = ASDisplayNode()
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.textNode = TextNode()
        
        self.titleNode = TextNode()
        
        super.init(layerBacked: false, dynamicBounce: true, rotated: true)
        
        self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        
        self.addSubnode(self.offsetContainer)
        self.offsetContainer.addSubnode(self.backgroundNode)
        self.offsetContainer.addSubnode(self.titleNode)
        self.offsetContainer.addSubnode(self.textNode)
        self.wantsTrailingItemSpaceUpdates = true
    }
    
    deinit {
        self.fetchDisposable.dispose()
    }
    
//    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
//        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
//        
//        let maskLayer = CAGradientLayer()
//        maskLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
//        maskLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
//        maskLayer.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
//        maskLayer.locations = [0.0, 0.0]
//        maskLayer.frame = self.bounds
//        self.layer.mask = maskLayer
//        
//        let animation = CABasicAnimation(keyPath: "locations")
//        animation.fromValue = [0.0, 0.0]
//        animation.toValue = [0.0, 1.0]
//        animation.duration = duration
//        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
//        animation.delegate = self
//        maskLayer.add(animation, forKey: "locationAnimation")
//    }
//    
//    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
//        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
//        
//        let maskLayer = CAGradientLayer()
//        maskLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
//        maskLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
//        maskLayer.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
//        maskLayer.locations = [0.0, 0.0]
//        maskLayer.frame = self.bounds
//        self.layer.mask = maskLayer
//        
//        let animation = CABasicAnimation(keyPath: "locations")
//        animation.fromValue = [0.0, 0.0]
//        animation.toValue = [0.0, 1.0]
//        animation.duration = duration
//        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
//        animation.delegate = self
//        maskLayer.add(animation, forKey: "locationAnimation")
//    }
    
    func updateShimmerParameters() {
        guard let shimmerView = self.shimmerView, let borderShimmerView = self.borderShimmerView else {
            return
        }
        
        let color = theme?.theme.rootController.navigationBar.accentTextColor ?? .white
        let alpha: CGFloat
        let borderAlpha: CGFloat
        
        shimmerView.update(backgroundColor: .clear, foregroundColor: color.withAlphaComponent(0.3), gradientSize: 50.0, globalTimeOffset: false, duration: 1.2, horizontal: true)
        borderShimmerView.update(backgroundColor: .clear, foregroundColor: color.withAlphaComponent(1.0), gradientSize: 60.0, globalTimeOffset: false, duration: 1.2, horizontal: true)
        
        
        
        //shimmerView.layer.compositingFilter = compositingFilter
        //borderShimmerView.layer.compositingFilter = compositingFilter
    }
    
    private func setupGloss() {
        if self.gloss {
            if self.shimmerView == nil {
                let shimmerView = ShimmerEffectForegroundView()
                self.shimmerView = shimmerView
                
                let borderView = UIView()
                borderView.isUserInteractionEnabled = false
                self.borderView = borderView
                
                let borderMaskView = UIView()
                borderMaskView.layer.borderWidth = 2.0
                borderMaskView.layer.borderColor = UIColor.white.cgColor
                borderView.mask = borderMaskView
                self.borderMaskView = borderMaskView
                
                let borderShimmerView = ShimmerEffectForegroundView()
                self.borderShimmerView = borderShimmerView
                borderView.addSubview(borderShimmerView)
                
                self.offsetContainer.view.insertSubview(shimmerView, aboveSubview: self.backgroundNode.view)
                self.offsetContainer.view.insertSubview(borderView, aboveSubview: self.backgroundNode.view)
                
                self.updateShimmerParameters()
                
                self.shimmerView?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
        } else if self.shimmerView != nil {
            self.shimmerView?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.8) { _ in
                self.shimmerView?.removeFromSuperview()
                self.borderView?.removeFromSuperview()
                self.borderMaskView?.removeFromSuperview()
                self.borderShimmerView?.removeFromSuperview()
                
                self.shimmerView = nil
                self.borderView = nil
                self.borderMaskView = nil
                self.borderShimmerView = nil
            }
        }
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] point in
            if let strongSelf = self {
                let tapAction = strongSelf.tapActionAtPoint(point, gesture: .tap, isEstimating: true)
                switch tapAction.content {
                case .none:
                    break
                case .ignore:
                    return .fail
                case .url, .peerMention, .textMention, .botCommand, .hashtag, .instantPage, .wallpaper, .theme, .call, .openMessage, .timecode, .bankCard, .tooltip, .openPollResults, .copy, .largeEmoji, .customEmoji:
                    return .waitForSingleTap
                }
            }
            
            return .waitForDoubleTap
        }
        recognizer.highlight = { [weak self] point in
            if let strongSelf = self {
                strongSelf.updateTouchesAtPoint(point)
            }
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        super.updateAbsoluteRect(rect, within: containerSize)
        
        self.absolutePosition = (rect, containerSize)
        if let backgroundContent = self.backgroundContent {
            var backgroundFrame = backgroundContent.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += containerSize.height - rect.minY
            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
        }
    }
    
    public func asyncLayout() -> (_ item: ChatSummaryItem, _ width: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let currentTextAndEntities = self.currentTextAndEntities
        let currentTheme = self.theme
        
        return { [weak self] item, params in
            self?.item = item
            
            let itemText = (item.text == "") ? "\n\n" : item.text
            
            var updatedBackgroundImage: UIImage?
            if currentTheme != item.presentationData.theme {
                updatedBackgroundImage = PresentationResourcesChat.chatInfoItemBackgroundImage(item.presentationData.theme.theme, wallpaper: !item.presentationData.theme.wallpaper.isEmpty)
            }
                        
            var updatedTextAndEntities: (String, [MessageTextEntity])
            if let (text, entities) = currentTextAndEntities {
                if text == itemText {
                    updatedTextAndEntities = (text, entities)
                } else {
                    updatedTextAndEntities = (itemText, generateTextEntities(itemText, enabledTypes: .all))
                }
            } else {
                updatedTextAndEntities = (itemText, generateTextEntities(itemText, enabledTypes: .all))
            }
            
            let attributedText = stringWithAppliedEntities(updatedTextAndEntities.0, entities: updatedTextAndEntities.1, baseColor: item.presentationData.theme.theme.chat.message.infoPrimaryTextColor, linkColor: item.presentationData.theme.theme.chat.message.infoLinkTextColor, baseFont: messageFont, linkFont: messageFont, boldFont: messageBoldFont, italicFont: messageItalicFont, boldItalicFont: messageBoldItalicFont, fixedFont: messageFixedFont, blockQuoteFont: messageFont, message: nil, adjustQuoteFontSize: true)
            
            let horizontalEdgeInset: CGFloat = 10.0 + params.leftInset
            let horizontalContentInset: CGFloat = 16.0
            let verticalItemInset: CGFloat = 10.0
            let verticalContentInset: CGFloat = 12.0
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: messageBoldFont, textColor: item.presentationData.theme.theme.chat.message.infoPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - horizontalEdgeInset * 2.0 - horizontalContentInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - horizontalEdgeInset * 2.0 - horizontalContentInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .left, cutout: nil, insets: UIEdgeInsets()))
            
            let textWidth = params.width - horizontalEdgeInset * 2.0 - horizontalContentInset * 2.0
            let textSpacing: CGFloat = 1.0
            let textSize = CGSize(width: textWidth, height: (titleLayout.size.height + (titleLayout.size.width.isZero ? 0.0 : textSpacing) + textLayout.size.height))
            
            
            let backgroundFrame = CGRect(origin: CGPoint(x: floor((params.width - textSize.width - horizontalContentInset * 2.0) / 2.0), y: verticalItemInset + 4.0), size: CGSize(width: textSize.width + horizontalContentInset * 2.0, height: textSize.height + verticalContentInset * 2.0))
            let titleFrame = CGRect(
                origin: CGPoint(
                    x: backgroundFrame.origin.x + (backgroundFrame.size.width - titleLayout.size.width) / 2,
                    y: backgroundFrame.origin.y + verticalContentInset
                ),
                size: titleLayout.size
            )
            let textFrame = CGRect(origin: CGPoint(x: backgroundFrame.origin.x + horizontalContentInset, y: backgroundFrame.origin.y + verticalContentInset + titleLayout.size.height + (titleLayout.size.width.isZero ? 0.0 : textSpacing)), size: CGSize(width: textWidth, height: textLayout.size.height))
            
            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: textLayout.size.height + verticalItemInset * 2.0 + verticalContentInset * 2.0 + titleLayout.size.height + (titleLayout.size.width.isZero ? 0.0 : textSpacing) - 3.0), insets: UIEdgeInsets())
            return (itemLayout, { _ in
                if let strongSelf = self {
                    strongSelf.theme = item.presentationData.theme
                    
                    if let updatedBackgroundImage = updatedBackgroundImage {
                        strongSelf.backgroundNode.image = updatedBackgroundImage
                    }
                    
                    strongSelf.controllerInteraction = item.controllerInteraction
                    strongSelf.currentTextAndEntities = updatedTextAndEntities
                    
                    strongSelf.gloss = item.text == ""
                    
                    
                    DispatchQueue.main.async {
                        let _ = titleApply()
                        let _ = textApply()
                        
                        strongSelf.textNode.frame = CGRect(x: textFrame.origin.x, y: textFrame.origin.y, width: textFrame.size.width, height:  textFrame.size.height)
                    }
                    
                    UIView.animate(withDuration: 0.18) {
                        strongSelf.backgroundNode.frame = backgroundFrame
                    }
                    strongSelf.offsetContainer.frame = CGRect(origin: CGPoint(), size: itemLayout.contentSize)
                        
                    strongSelf.titleNode.frame = titleFrame
                    
                    if let shimmerView = strongSelf.shimmerView, let borderView = strongSelf.borderView, let borderMaskView = strongSelf.borderMaskView, let borderShimmerView = strongSelf.borderShimmerView {
                        UIView.animate(withDuration: 0.18) {
                            shimmerView.frame = backgroundFrame
                            borderView.frame = backgroundFrame
                            borderMaskView.frame = CGRect(origin: CGPoint(), size: backgroundFrame.size)
                            borderShimmerView.frame = CGRect(origin: CGPoint(), size: backgroundFrame.size)
                        }
                        
                        let size = CGSize(width: itemLayout.size.width, height: 400.0)
                        
                        shimmerView.updateAbsoluteRect(CGRect(origin: CGPoint(x: size.width * 2.0, y: 0.0), size: size), within: CGSize(width: size.width * 6.0, height: size.height))
                        borderShimmerView.updateAbsoluteRect(CGRect(origin: CGPoint(x: size.width * 2.0, y: 0.0), size: size), within: CGSize(width: size.width * 6.0, height: size.height))
                        
                        shimmerView.layer.cornerRadius = 17.0
                        borderMaskView.layer.cornerRadius = 17.0
                        borderView.layer.cornerRadius = 17.0
                        borderShimmerView.layer.cornerRadius = 17.0
                    }
                    
                    if item.controllerInteraction.presentationContext.backgroundNode?.hasExtraBubbleBackground() == true {
                        if strongSelf.backgroundContent == nil, let backgroundContent = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                            backgroundContent.clipsToBounds = true

                            strongSelf.backgroundContent = backgroundContent
                            strongSelf.offsetContainer.insertSubnode(backgroundContent, at: 0)
                        }
                    } else {
                        strongSelf.backgroundContent?.removeFromSupernode()
                        strongSelf.backgroundContent = nil
                    }
                    
                    if let backgroundContent = strongSelf.backgroundContent {
                        strongSelf.backgroundNode.isHidden = true
                        backgroundContent.cornerRadius = item.presentationData.chatBubbleCorners.mainRadius
                        if backgroundContent.frame != .zero {
                            UIView.animate(withDuration: 0.18) {
                                backgroundContent.frame = backgroundFrame
                            }
                        } else {
                            backgroundContent.frame = backgroundFrame
                        }
                        
                        if let (rect, containerSize) = strongSelf.absolutePosition {
                            var backgroundFrame = backgroundContent.frame
                            backgroundFrame.origin.x += rect.minX
                            backgroundFrame.origin.y += containerSize.height - rect.minY
                            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
                        }
                    } else {
                        strongSelf.backgroundNode.isHidden = false
                    }
                }
            })
        }
    }
    
    override public func updateTrailingItemSpace(_ height: CGFloat, transition: ContainedViewLayoutTransition) {
        if height.isLessThanOrEqualTo(0.0) {
            transition.updateFrame(node: self.offsetContainer, frame: CGRect(origin: CGPoint(), size: self.offsetContainer.bounds.size))
        } else {
            transition.updateFrame(node: self.offsetContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: -floorToScreenPixels(height / 2.0)), size: self.offsetContainer.bounds.size))
        }
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
        self.layer.animateScale(from: 0.1, to: 1.0, duration: duration)
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
        self.layer.animateScale(from: 0.1, to: 1.0, duration: duration)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
    }
    
    override public func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let result = super.point(inside: point, with: event)
        let extra = self.offsetContainer.frame.contains(point)
        return result || extra
    }
    
    public func updateTouchesAtPoint(_ point: CGPoint?) {
        if let item = self.item {
            var rects: [CGRect]?
            if let point = point {
                let textNodeFrame = self.textNode.frame
                if let (index, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - self.offsetContainer.frame.minX - textNodeFrame.minX, y: point.y - self.offsetContainer.frame.minY - textNodeFrame.minY)) {
                    let possibleNames: [String] = [
                        TelegramTextAttributes.URL,
                        TelegramTextAttributes.PeerMention,
                        TelegramTextAttributes.PeerTextMention,
                        TelegramTextAttributes.BotCommand,
                        TelegramTextAttributes.Hashtag
                    ]
                    for name in possibleNames {
                        if let _ = attributes[NSAttributedString.Key(rawValue: name)] {
                            rects = self.textNode.attributeRects(name: name, at: index)
                            break
                        }
                    }
                }
            }
            
            if let rects = rects {
                let linkHighlightingNode: LinkHighlightingNode
                if let current = self.linkHighlightingNode {
                    linkHighlightingNode = current
                } else {
                    linkHighlightingNode = LinkHighlightingNode(color: item.presentationData.theme.theme.chat.message.incoming.linkHighlightColor)
                    self.linkHighlightingNode = linkHighlightingNode
                    self.offsetContainer.insertSubnode(linkHighlightingNode, belowSubnode: self.textNode)
                }
                linkHighlightingNode.frame = self.textNode.frame
                linkHighlightingNode.updateRects(rects)
            } else if let linkHighlightingNode = self.linkHighlightingNode {
                self.linkHighlightingNode = nil
                linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                    linkHighlightingNode?.removeFromSupernode()
                })
            }
        }
    }
    
    public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        let textNodeFrame = self.textNode.frame
        if let (index, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - self.offsetContainer.frame.minX - textNodeFrame.minX, y: point.y - self.offsetContainer.frame.minY - textNodeFrame.minY)) {
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                if let (attributeText, fullText) = self.textNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                    concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
                }
                return ChatMessageBubbleContentTapAction(content: .url(ChatMessageBubbleContentTapAction.Url(url: url, concealed: concealed)))
            } else if let peerMention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                return ChatMessageBubbleContentTapAction(content: .peerMention(peerId: peerMention.peerId, mention: peerMention.mention, openProfile: false))
            } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                return ChatMessageBubbleContentTapAction(content: .textMention(peerName))
            } else if let botCommand = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                return ChatMessageBubbleContentTapAction(content: .botCommand(botCommand))
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return ChatMessageBubbleContentTapAction(content: .hashtag(hashtag.peerName, hashtag.hashtag))
            } else {
                return ChatMessageBubbleContentTapAction(content: .none)
            }
        } else {
            return ChatMessageBubbleContentTapAction(content: .none)
        }
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                    case .tap:
                        let tapAction = self.tapActionAtPoint(location, gesture: gesture, isEstimating: false)
                        switch tapAction.content {
                        case .none, .ignore:
                            break
                        case let .url(url):
                            self.item?.controllerInteraction.openUrl(ChatControllerInteraction.OpenUrl(url: url.url, concealed: url.concealed, progress: tapAction.activate?()))
                        case let .peerMention(peerId, _, _):
                            if let item = self.item {
                                let _ = (item.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                                |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
                                    if let peer = peer {
                                        self?.item?.controllerInteraction.openPeer(peer, .chat(textInputState: nil, subject: nil, peekData: nil), nil, .default)
                                    }
                                })
                            }
                        case let .textMention(name):
                            self.item?.controllerInteraction.openPeerMention(name, tapAction.activate?())
                        case let .botCommand(command):
                            self.item?.controllerInteraction.sendBotCommand(nil, command)
                        case let .hashtag(peerName, hashtag):
                            self.item?.controllerInteraction.openHashtag(peerName, hashtag)
                        default:
                            break
                            }
                        case .longTap, .doubleTap:
                            if let item = self.item, self.backgroundNode.frame.contains(location) {
                                let tapAction = self.tapActionAtPoint(location, gesture: gesture, isEstimating: false)
                                switch tapAction.content {
                                case .none, .ignore:
                                    break
                                case let .url(url):
                                    item.controllerInteraction.longTap(.url(url.url), nil)
                                case let .peerMention(peerId, mention, _):
                                    item.controllerInteraction.longTap(.peerMention(peerId, mention), nil)
                                case let .textMention(name):
                                    item.controllerInteraction.longTap(.mention(name), nil)
                                case let .botCommand(command):
                                    item.controllerInteraction.longTap(.command(command), nil)
                                case let .hashtag(_, hashtag):
                                    item.controllerInteraction.longTap(.hashtag(hashtag), nil)
                                default:
                                    break
                                }
                            }
                        default:
                            break
                    }
                }
            default:
                break
        }
    }
}

