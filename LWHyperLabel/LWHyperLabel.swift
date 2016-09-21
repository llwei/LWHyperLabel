//
//  LWHyperLabel.swift
//  LWHyperLabel
//
//  Created by 赖灵伟 on 16/4/27.
//  Copyright © 2016年 lailingwei. All rights reserved.
//
//  富文本Label

import UIKit

/**
 超链接的类型
 
 - UserHandle: 以"@"开头的用户名
 - Hashtag:    以"#"开头标签
 - URL:        http链接
 - Phone:      电话
 - Address:    地址
 */
@objc enum LWHyperLabelType: Int {
    case userHandle     = 1
    case hashtag        = 2
    case url            = 3
    case phone          = 4
    case address        = 5
}

// keys
private let kLabelLinkTypeKey = "kLabelLinkTypeKey"
private let kLabelRangeKey = "kLabelRangeKey"
private let kLabelLinkKey = "kLabelLinkKey"

class LWHyperLabel: UILabel, NSLayoutManagerDelegate {

    // MARK: Properties
    
    /** ****************************************************************************************** **
     * @name Setting the link detector
     ** ****************************************************************************************** **/
    
    /**是否自动检测超链接*/
    @IBInspectable var autoLinkDetectionEnabled: Bool = true {
        didSet {
            // Make sure the text is updated properly
            updateTextStoreWithText()
        }
    }
    
    /**检测超链接的类型组合*/
    internal var linkDetectionTypes = [
        LWHyperLabelType.userHandle,
        LWHyperLabelType.hashtag,
        LWHyperLabelType.url,
        LWHyperLabelType.phone,
        LWHyperLabelType.address] {
        
        didSet {
            // Make sure the text is updated properly
            updateTextStoreWithText()
        }
    }
    
    /**忽略的超链接关键字集合*/
    fileprivate var _ignoredKeywords: NSSet?
    internal var ignoredKeywords: NSSet? {
        set {
            if let new = newValue {
                _ignoredKeywords = new
            } else {
                self.ignoredKeywords = newValue
            }
            _ignoredKeywords = newValue
            updateTextStoreWithText()
        }
        get {
            return self._ignoredKeywords
        }
    }
    
    
    /** ****************************************************************************************** **
     * @name Format & Appearance
     ** ****************************************************************************************** **/
    
    /**超链接高亮状态背景颜色*/
    @IBInspectable var selectedLinkBgColor: UIColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
    
    /**是否使用系统默认的URL样式（下划线 + 蓝色）*/
    @IBInspectable var useSystemURLStyle: Bool = false {
        didSet {
            // Force refresh
            forceRefresh()
        }
    }
    
    
    /** ****************************************************************************************** **
     * @name Callbacks
     ** ****************************************************************************************** **/
    
    /**点击 LWHyperLabelTypeUserHandle 类型回调*/
    fileprivate var userHandleLinkTapHandler: ((_ label: LWHyperLabel, _ string: String, _ range: NSRange) -> Void)?
    
    /**点击 LWHyperLabelTypeHashtag 类型回调*/
    fileprivate var hashtagLinkTapHandler: ((_ label: LWHyperLabel, _ string: String, _ range: NSRange) -> Void)?
    
    /**点击 LWHyperLabelTypeURL 类型回调*/
    fileprivate var urlLinkTapHandler: ((_ label: LWHyperLabel, _ string: String, _ range: NSRange) -> Void)?
    
    /**点击 LWHyperLabelTypePhone 类型回调*/
    fileprivate var phoneLinkTapHandler: ((_ label: LWHyperLabel, _ string: String, _ range: NSRange) -> Void)?
    
    /**点击 LWHyperLabelTypeAddress 类型回调*/
    fileprivate var addressLinkTapHandler: ((_ label: LWHyperLabel, _ string: String, _ range: NSRange) -> Void)?
    
    
    /** ****************************************************************************************** **
     * @name Private
     ** ****************************************************************************************** **/
    
    // Used to control layout of glyphs and rendering
    fileprivate var layoutManager = NSLayoutManager()
    
    // Specifies the space in which to render text
    fileprivate var textContainer = NSTextContainer()
    
    // Backing storage for text that is rendered by the layout manager
    fileprivate var textStorage: NSTextStorage?
    
    // State used to trag if the user has dragged during a touch
    fileprivate var isTouchMoved: Bool = false
    
    // During a touch, range of text that is displayed as selected
    fileprivate var selectedRange: NSRange = NSMakeRange(0, 0) {
        didSet {
            // Remove the current selection if the selection is changing
            if oldValue.length > 0 && !NSEqualRanges(oldValue, selectedRange) {
                textStorage?.removeAttribute(NSBackgroundColorAttributeName, range: oldValue)
            }
            
            // Apply the new selection to the text
            if selectedRange.length > 0 && selectedLinkBgColor != UIColor.clear {
                textStorage?.addAttribute(NSBackgroundColorAttributeName, value: selectedLinkBgColor, range: selectedRange)
            }
            
            setNeedsDisplay()
        }
    }
    
    
    fileprivate var linkTypeAttributes = NSMutableDictionary()
    
    // [[kLabelLinkTypeKey : xxx, kLabelRangeKey : xxx, kLabelLinkKey : xxx]]
    fileprivate var linkRanges = [[String : AnyObject]]()
    
    
    /** ****************************************************************************************** **
     * @name Override
     ** ****************************************************************************************** **/
    
    override var numberOfLines: Int {
        didSet {
            textContainer.maximumNumberOfLines = numberOfLines
        }
    }
    
    override var text: String? {
        didSet {
            forceRefresh()
        }
    }
    
    override var attributedText: NSAttributedString? {
        didSet {
            if let attriText = attributedText {
                updateTextStoreWithAttributedString(attriText)
            }
        }
    }
    
    override var frame: CGRect {
        didSet {
            textContainer.size = bounds.size
        }
    }
    
    override var bounds: CGRect {
        didSet {
            textContainer.size = bounds.size
        }
    }
    
    
    
    // MARK: Text and Style management
    
    
    /**
     根据 超链接类型 获取对应字段的attributes
     
     - parameter linkType: 超链接类型
     
     - returns: 默认的attributes包含了 color 属性
     */
    fileprivate func attributesForLinkType(_ linkType: LWHyperLabelType.RawValue) -> [String : AnyObject] {
        
        if let attributes = linkTypeAttributes[linkType] as? [String : AnyObject] {
            return attributes
        }
        
        return [NSForegroundColorAttributeName : tintColor]
    }
    
    
    /**
     根据 超链接类型 设置对应字段的attributes属性
     
     - parameter attributes: attributes属性
     - parameter linkType:   超链接类型
     */
    fileprivate func setAttributes(_ attributes: [String : AnyObject]?, forLinkType linkType: LWHyperLabelType.RawValue) {
        
        if let attributesDic = attributes {
            linkTypeAttributes[linkType] = attributesDic
        } else {
            linkTypeAttributes.removeObject(forKey: linkType)
        }
        
        // Force refresh
        forceRefresh()
    }
    
    
    /**
     根据坐标点返回对应位置的超链接额字典类型数据
     
     - parameter point: 坐标点
     
     - returns: 超链接字典数据，有可能为nil，keys包括 kLabelLinkTypeKey、kLabelRangeKey、kLabelLinkKey
     */
    fileprivate func linkAtPoint(_ point: CGPoint) -> [String : AnyObject]? {
        
        var location = point
        
        // Do nothing if we have no text
        if let storage = textStorage {
            if (storage.string as NSString).length == 0 {
                return nil
            }
        } else {
            return nil
        }
        
        // Work out the offset of the text in the view
        let textOffset = calcGlyphsPositionInView()
        
        // Get the touch location and use text offset to convert to text cotainer coords
        location.x -= textOffset.x
        location.y -= textOffset.y
        
        let touchedChar = layoutManager.glyphIndex(for: location, in: textContainer)
        
        // If the touch is in white space after the last glyph on the line we don't count it as a hit on the text
        var lineRange: NSRange = NSMakeRange(0, 0)
        let lineRect = layoutManager.lineFragmentUsedRect(forGlyphAt: touchedChar, effectiveRange: &lineRange)
        if !lineRect.contains(location) {
            return nil
        }
        
        // Find the word that was touched and call the detection block
        for dict in linkRanges {
            if let range = dict[kLabelRangeKey]?.rangeValue {
                if touchedChar >= range.location && touchedChar < (range.location + range.length) {
                    return dict
                }
            }
        }
        
        return nil
    }
    
    
    
    // MARK: Construction
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        // 初始化
        setupTextSystem()
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        // 初始化
        setupTextSystem()
    }
    
    
    // 初始化
    fileprivate func setupTextSystem() {
        
        // Set textContainer up to match our label properties
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = numberOfLines
        textContainer.lineBreakMode = lineBreakMode
        textContainer.size = frame.size
        
        // layoutManager
        layoutManager.delegate = self
        layoutManager.addTextContainer(textContainer)
        
        // Attach the layoutManager to the container and storage
        textContainer.layoutManager = layoutManager
        
        // Establich the text store with our current text
        updateTextStoreWithText()
    }
    
    deinit {
        print("\(NSStringFromClass(LWHyperLabel.self)).deinit")
    }
    
    
    // MARK: Text Storage Management
    
    
    /**Update our storage from eiter the attributedString or the plain text*/
    fileprivate func updateTextStoreWithText() {
        
        if let attriText = attributedText {
            updateTextStoreWithAttributedString(attriText)
        } else if let textString = text {
            let attriText = NSAttributedString(string: textString, attributes: attributesFromProperties())
            updateTextStoreWithAttributedString(attriText)
        } else {
            let attriText = NSAttributedString(string: "", attributes: attributesFromProperties())
            updateTextStoreWithAttributedString(attriText)
        }
        
        setNeedsDisplay()
    }
    
    
    /**Update our storage from the attributedString*/
    fileprivate func updateTextStoreWithAttributedString(_ attributedString: NSAttributedString) {
        
        var attriText = attributedString
        if attriText.length != 0 {
            // 对attributedString中的 NSParagraphStyle 进行优化
            attriText = LWHyperLabel.sanitizeAttributedString(attributedString)
        }
        
        if autoLinkDetectionEnabled && attriText.length != 0 {
            // 获取超链接字段的range数组 [[kLabelLinkTypeKey : xxx, kLabelRangeKey : xxx, kLabelLinkKey : xxx]]
            linkRanges = fetchRangeForLinks(attributedString)
            
            // 根据 所识别的超链接属性字典数组 使得原字符串 attributedString化
            attriText = addLinkAttributesToAttributedString(attriText, linkRanges: linkRanges)
            
        } else {
            linkRanges.removeAll()
        }
        
        if let storage = textStorage {
            // Set the string on the storage
            storage.setAttributedString(attriText)
        } else {
            // Create a new text storage and attach it correctly to the layout manager
            textStorage = NSTextStorage(attributedString: attriText)
            textStorage?.addLayoutManager(layoutManager)
            layoutManager.textStorage = textStorage
        }
        
    }
    
    
    /**
     Returns attributed string attributes based on the text properties set on the label
     基本普通label.text，创建并返回自定义默认attributedString
     */
    fileprivate func attributesFromProperties() -> [String : AnyObject] {
        
        // Setup shadow attributes
        let shadow = NSShadow()
        if let color = shadowColor {
            shadow.shadowColor = color
            shadow.shadowOffset = shadowOffset
        } else {
            shadow.shadowColor = nil
            shadow.shadowOffset = CGSize(width: 0, height: -1)
        }
        
        // Setup color attributes
        var color = textColor
        if !isEnabled {
            color = UIColor.lightGray
        } else if isHighlighted {
            color = highlightedTextColor
        }
        
        // Setup paragraph attributes
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = textAlignment
        
        // Create teh dictionary
        let attributes = [
            NSFontAttributeName : font,
            NSForegroundColorAttributeName : color,
            NSShadowAttributeName : shadow,
            NSParagraphStyleAttributeName : paragraph] as [String : Any]
        
        return attributes as [String : AnyObject]
    }
    
    
    /**
     获取超链接字段的range数组
     
     - parameter text: attributed字符串
     
     - returns: 带有超链接相关描述字典的数组 [[kLabelLinkTypeKey : xxx, kLabelRangeKey : xxx, kLabelLinkKey : xxx]]
     */
    fileprivate func fetchRangeForLinks(_ text: NSAttributedString) -> [[String : AnyObject]] {
        
        var rangesForLinks = [[String : AnyObject]]()
        
        if linkDetectionTypes.contains(LWHyperLabelType.userHandle) {
            // 以"@"开头的用户名
            rangesForLinks.append(contentsOf: rangesForUserHandles(text.string))
        }
        
        if linkDetectionTypes.contains(LWHyperLabelType.hashtag) {
            // 以"#"开头标签
            rangesForLinks.append(contentsOf: rangesForHashtags(text.string))
        }
        
        if linkDetectionTypes.contains(LWHyperLabelType.url) {
            // http链接
            if let attriText = attributedText {
                rangesForLinks.append(contentsOf: rangesForURLs(attriText))
            }
        }
        
        if linkDetectionTypes.contains(LWHyperLabelType.phone) {
            // 电哈
            if let attriText = attributedText {
                rangesForLinks.append(contentsOf: rangesForPhone(attriText))
            }
        }
        
        if linkDetectionTypes.contains(LWHyperLabelType.address) {
            // 地址
            if let attriText = attributedText {
                rangesForLinks.append(contentsOf: rangesForAddress(attriText))
            }
        }
        
        return rangesForLinks
    }
    
    
    /**
     获取 以"@"开头的用户名 超链接字典属性数组
     
     - parameter textString: 原始字符字段
     
     - returns: 带有超链接相关描述字典的数组 [[kLabelLinkTypeKey : xxx, kLabelRangeKey : xxx, kLabelLinkKey : xxx]]
     */
    fileprivate func rangesForUserHandles(_ textString: String) -> [[String : AnyObject]] {
        
        var rangesForUserHandles = [[String : AnyObject]]()
        
        do {
            // Setup a regular expression for user handles and hashtags
            let regex = try NSRegularExpression(pattern: "(?<!\\w)@([\\w\\_]+)?", options: NSRegularExpression.Options.caseInsensitive)
            
            // Run the expression and get matches
            let matches = regex.matches(in: textString, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSMakeRange(0, (textString as NSString).length))
            
            // Add all our ranges to the result
            for match in matches {
                let matchRange = match.range
                let matchString = (textString as NSString).substring(with: matchRange)
                
                if !ignoreMatch(matchString) {
                    rangesForUserHandles.append([
                        kLabelLinkTypeKey : LWHyperLabelType.userHandle.rawValue as AnyObject,
                        kLabelRangeKey : NSValue(range: matchRange),
                        kLabelLinkKey : matchString as AnyObject])
                }
            }
            
        } catch let error as NSError {
            print(error.localizedDescription)
        }
        
        return rangesForUserHandles
    }
    
    
    /**
     获取 以"#"开头标签 超链接字典属性数组
     
     - parameter textString: 原始字符字段
     
     - returns: 带有超链接相关描述字典的数组 [[kLabelLinkTypeKey : xxx, kLabelRangeKey : xxx, kLabelLinkKey : xxx]]
     */
    fileprivate func rangesForHashtags(_ textString: String) -> [[String : AnyObject]] {
        
        var rangesForHashtags = [[String : AnyObject]]()
        
        do {
            // Setup a regular expression for user handles and hashtags
            let regex = try NSRegularExpression(pattern: "(?<!\\w)#([\\w\\_]+)?", options: NSRegularExpression.Options.caseInsensitive)
            
            // Run the expression and get matches
            let matches = regex.matches(in: textString, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSMakeRange(0, (textString as NSString).length))
            
            // Add all our ranges to the result
            for match in matches {
                let matchRange = match.range
                let matchString = (textString as NSString).substring(with: matchRange)
                
                if !ignoreMatch(matchString) {
                    rangesForHashtags.append([
                        kLabelLinkTypeKey : LWHyperLabelType.hashtag.rawValue as AnyObject,
                        kLabelRangeKey : NSValue(range: matchRange),
                        kLabelLinkKey : matchString as AnyObject])
                }
            }
            
        } catch let error as NSError {
            print(error.localizedDescription)
        }
        
        return rangesForHashtags
    }
    
    
    /**
     获取 http链接 超链接字典属性数组
     
     - parameter textString: 原始字符字段
     
     - returns: 带有超链接相关描述字典的数组 [[kLabelLinkTypeKey : xxx, kLabelRangeKey : xxx, kLabelLinkKey : xxx]]
     */
    fileprivate func rangesForURLs(_ textString: NSAttributedString) -> [[String : AnyObject]] {
        
        var rangesForURLs = [[String : AnyObject]]()
        
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let plainText = textString.string
            let matches = detector.matches(in: plainText, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSMakeRange(0, textString.length))
            
            // Add a range entry for every url we found
            for match in matches {
                let matchRange = match.range
                
                // If there's a link embedded in the attributes, use that instead of the raw text
                var realURL: String!
                if let url = textString.attribute(NSLinkAttributeName, at: matchRange.location, effectiveRange: nil) as? String {
                    realURL = url
                } else {
                    realURL = (plainText as NSString).substring(with: matchRange)
                }
                
                if !ignoreMatch(realURL) {
                    if match.resultType == NSTextCheckingResult.CheckingType.link {
                        rangesForURLs.append([
                            kLabelLinkTypeKey : LWHyperLabelType.url.rawValue as AnyObject,
                            kLabelRangeKey : NSValue(range: matchRange),
                            kLabelLinkKey : realURL as AnyObject])
                    }
                }
            }
            
        } catch let error as NSError {
            print(error.localizedDescription)
        }
        
        return rangesForURLs
    }
    
    
    /**
     获取 电话 超链接字典属性数组
     
     - parameter textString: 原始字符字段
     
     - returns: 带有超链接相关描述字典的数组 [[kLabelLinkTypeKey : xxx, kLabelRangeKey : xxx, kLabelLinkKey : xxx]]
     */
    fileprivate func rangesForPhone(_ textString: NSAttributedString) -> [[String : AnyObject]] {
        
        var rangesForPhone = [[String : AnyObject]]()
        
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
            let plainText = textString.string
            let matches = detector.matches(in: plainText, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSMakeRange(0, textString.length))
            
            // Add a range entry for every url we found
            for match in matches {
                let matchRange = match.range
                
                // If there's a link embedded in the attributes, use that instead of the raw text
                var realURL: String!
                if let url = textString.attribute(NSLinkAttributeName, at: matchRange.location, effectiveRange: nil) as? String {
                    realURL = url
                } else {
                    realURL = (plainText as NSString).substring(with: matchRange)
                }
                
                if !ignoreMatch(realURL) {
                    if match.resultType == NSTextCheckingResult.CheckingType.phoneNumber {
                        rangesForPhone.append([
                            kLabelLinkTypeKey : LWHyperLabelType.phone.rawValue as AnyObject,
                            kLabelRangeKey : NSValue(range: matchRange),
                            kLabelLinkKey : realURL as AnyObject])
                    }
                }
            }
            
        } catch let error as NSError {
            print(error.localizedDescription)
        }
        
        return rangesForPhone
    }
    
    
    /**
     获取 地址 超链接字典属性数组
     
     - parameter textString: 原始字符字段
     
     - returns: 带有超链接相关描述字典的数组 [[kLabelLinkTypeKey : xxx, kLabelRangeKey : xxx, kLabelLinkKey : xxx]]
     */
    fileprivate func rangesForAddress(_ textString: NSAttributedString) -> [[String : AnyObject]] {
        
        var rangesForAddress = [[String : AnyObject]]()
        
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue)
            let plainText = textString.string
            let matches = detector.matches(in: plainText, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSMakeRange(0, textString.length))
            
            // Add a range entry for every url we found
            for match in matches {
                let matchRange = match.range
                
                // If there's a link embedded in the attributes, use that instead of the raw text
                var realURL: String!
                if let url = textString.attribute(NSLinkAttributeName, at: matchRange.location, effectiveRange: nil) as? String {
                    realURL = url
                } else {
                    realURL = (plainText as NSString).substring(with: matchRange)
                }
                
                if !ignoreMatch(realURL) {
                    if match.resultType == NSTextCheckingResult.CheckingType.address {
                        rangesForAddress.append([
                            kLabelLinkTypeKey : LWHyperLabelType.address.rawValue as AnyObject,
                            kLabelRangeKey : NSValue(range: matchRange),
                            kLabelLinkKey : realURL as AnyObject])
                    }
                }
            }
            
        } catch let error as NSError {
            print(error.localizedDescription)
        }
        
        return rangesForAddress
    }
    
    
    
    /**判断 string 中是否包含了 ignoredKeywords 中的字段*/
    fileprivate func ignoreMatch(_ string: String) -> Bool {
        if let keywords = ignoredKeywords {
            print(string.lowercased())
            return keywords.contains(string.lowercased())
        }
        return false
    }
    
    
    /**
     根据 所识别的超链接属性字典数组 使得原字符串 attributedString化
     
     - parameter string:     原字符串
     - parameter linkRanges: 带有超链接相关描述字典的数组 [[kLabelLinkTypeKey : xxx, kLabelRangeKey : xxx, kLabelLinkKey : xxx]]
     */
    fileprivate func addLinkAttributesToAttributedString(_ string: NSAttributedString, linkRanges: [[String : AnyObject]]) -> NSAttributedString {
        
        let attributedString = NSMutableAttributedString(attributedString: string)
        
        for dict in linkRanges {
            if let range = dict[kLabelRangeKey]?.rangeValue {
                if let linkType = dict[kLabelLinkTypeKey] as? Int {
                    let attributes = attributesForLinkType(linkType)
                    
                    // User our tint color to hilight the link
                    attributedString.addAttributes(attributes, range: range)
                    
                    // Add an URL attribute f this is a URL
                    if useSystemURLStyle && ((dict[kLabelLinkTypeKey] as? Int) == LWHyperLabelType.url.rawValue) {
                        // Add alink attribute using the stored link
                        if let realURL = dict[kLabelLinkKey] as? String {
                            attributedString.addAttribute(NSLinkAttributeName, value: realURL, range: range)
                        }
                    }
                }
            }
        }
        
        return attributedString
    }
    
    
    
    // MARK: Layout and Rendering
    
    
    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        
        // Use our text container to calculate the bounds required. First save our current text container setup
        let savedTextContainerSize = textContainer.size
        let savedTextContainerNumberOfLines = textContainer.maximumNumberOfLines
        
        // Apply the new potential bounds and number of lines
        textContainer.size = bounds.size
        textContainer.maximumNumberOfLines = numberOfLines
        
        // Measure the text with the new state
        var textBounds = layoutManager.usedRect(for: textContainer)
        
        // Position the bounds and round up the size for good measure
        textBounds.origin = bounds.origin
        textBounds.size.width = ceil(textBounds.size.width)
        textBounds.size.height = ceil(textBounds.size.height)
        
        if textBounds.size.height < bounds.size.height {
            // Take verial alignment into acount
            let offsetY = (bounds.size.height - textBounds.size.height) / 2.0
            textBounds.origin.y += offsetY
        }
        
        // Restore the old container state before we exit under any circumstances
        textContainer.size = savedTextContainerSize
        textContainer.maximumNumberOfLines = savedTextContainerNumberOfLines
        
        return textBounds
    }
    
    
    override func drawText(in rect: CGRect) {
        // Don't call super implementation. Might want to uncomment this out when
        // debugging layout and rendering problems.
        
        // Calculate the offset of the text in the view
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        let glyphsPosition = calcGlyphsPositionInView()
        
        // Drawing code
        layoutManager.drawBackground(forGlyphRange: glyphRange, at: glyphsPosition)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: glyphsPosition)
        
    }
    
    
    /**
     计算字符串在视图中的偏移量
     */
    fileprivate func calcGlyphsPositionInView() -> CGPoint {
        
        var textOffset = CGPoint.zero
        
        var textBounds = layoutManager.usedRect(for: textContainer)
        textBounds.size.width = ceil(textBounds.size.width)
        textBounds.size.height = ceil(textBounds.size.height)
        
        if textBounds.size.height < bounds.size.height {
            textOffset.y = (bounds.size.height - textBounds.size.height) / 2.0
        }
        
        return textOffset
    }
    
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update our container size when the view frame changes
        textContainer.size = bounds.size
    }
    
    
    
    // MARK: Interactions
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        isTouchMoved = false
        
        // Get the info for the touched link if there is one
        if let touchLocation = touches.first?.location(in: self) {
            if let touchedLink = linkAtPoint(touchLocation) {
                if let range = touchedLink[kLabelRangeKey]?.rangeValue {
                    selectedRange = range
                } else {
                    super.touchesBegan(touches, with: event)
                }
            } else {
                super.touchesBegan(touches, with: event)
            }
        } else {
            super.touchesBegan(touches, with: event)
        }
        
    }
    
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        isTouchMoved = true
    }
    
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        // If the user dragged their finger we ignore the touch
        if isTouchMoved {
            selectedRange = NSMakeRange(0, 0)
            return
        }
        
        // Get the info for the touched link if there is one
        if let touchLocation = touches.first?.location(in: self) {
            if let touchedLink = linkAtPoint(touchLocation) {
                if let range = touchedLink[kLabelRangeKey]?.rangeValue {
                    let touchedSubstring = touchedLink[kLabelLinkKey] as! String
                    let linkType = touchedLink[kLabelLinkTypeKey] as! Int
                    
                    receivedActionForLinkType(linkType, string: touchedSubstring, range: range)
                } else {
                    super.touchesBegan(touches, with: event)
                }
            } else {
                super.touchesBegan(touches, with: event)
            }
        } else {
            super.touchesBegan(touches, with: event)
        }
        
        selectedRange = NSMakeRange(0, 0)
    }
    
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        
        // Make sure we don't leave a selection when the touch is cancelled
        selectedRange = NSMakeRange(0, 0)
        
    }
    
    
    /**点击超链接回调*/
    fileprivate func receivedActionForLinkType(_ linkType: LWHyperLabelType.RawValue, string: String, range: NSRange) {
        
        switch linkType {
        case LWHyperLabelType.userHandle.rawValue:
            // 以"@"开头的用户名
            userHandleLinkTapHandler?(self, string, range)
        case LWHyperLabelType.hashtag.rawValue:
            // 以"#"开头标签
            hashtagLinkTapHandler?(self, string, range)
        case LWHyperLabelType.url.rawValue:
            // http链接
            urlLinkTapHandler?(self, string, range)
        case LWHyperLabelType.phone.rawValue:
            // 电话链接
            phoneLinkTapHandler?(self, string, range)
        case LWHyperLabelType.address.rawValue:
            // 地址链接
            addressLinkTapHandler?(self, string, range)
        default: break
        }
        
    }
    
    
    // MARK: Layout manager delegate
    
    
    func layoutManager(_ layoutManager: NSLayoutManager, shouldBreakLineByWordBeforeCharacterAt charIndex: Int) -> Bool {
        
        // Don't allow line breaks inside URLs
        var range: NSRange = NSMakeRange(0, 0)
        if let _ = layoutManager.textStorage?.attribute(NSLinkAttributeName, at: charIndex, effectiveRange: &range) as? URL {
            return !((charIndex > range.location) && (charIndex <= NSMaxRange(range)))
        }
        return true
    }
    
    /**对attributedString中的 NSParagraphStyle 进行优化*/
    class func sanitizeAttributedString(_ attributedString: NSAttributedString) -> NSAttributedString {
        
        /*
         Setup paragraph alignement properly, IB applies the line break style
         to the attributed string. The problem is that the text container then
         breaks at the first line of text. If we set the line break to wrapping
         then the text container defines the the break mode and it works.
         NOTE: This is either an Apple bug or something I've misunderstood
         */
        
        // Get the current paragraph style.
        // IB only allows a single paragraph so getting the style of the first char is fine
        
        var range: NSRange = NSMakeRange(0, 0)
        if let paragraphStyle = attributedString.attribute(NSParagraphStyleAttributeName, at: 0, effectiveRange: &range) as? NSParagraphStyle {
            
            if let mutableParagraphStyle = paragraphStyle.mutableCopy() as? NSMutableParagraphStyle {
                // Remove the line breaks
                mutableParagraphStyle.lineBreakMode = NSLineBreakMode.byWordWrapping
                
                // Apply new style
                let restyled = NSMutableAttributedString(attributedString: attributedString)
                restyled.addAttribute(NSParagraphStyleAttributeName, value: mutableParagraphStyle, range: NSMakeRange(0, restyled.length))
                
                return restyled
                
            } else {
                return attributedString
            }
            
        } else {
            return attributedString
        }
    }
    
    
    
    // MARK: Helper methods
    
    fileprivate func forceRefresh() {
        
        // Update our text store with an attributed string based on the original label text properties
        if let content = text {
            let attriText = NSAttributedString(string: content, attributes: attributesFromProperties())
            updateTextStoreWithAttributedString(attriText)
        } else {
            text = ""
        }
        
    }
    
    
    // MARK: - Public methods
    
    /**点击 LWHyperLabelTypeUserHandle 类型回调*/
    func tapHandlerForUserHandleLink(_ handler: ((_ label: LWHyperLabel, _ string: String, _ range: NSRange) -> Void)?) {
        userHandleLinkTapHandler = handler
    }
    
    /**点击 LWHyperLabelTypeHashtag 类型回调*/
    func tapHandlerForHashtagLink(_ handler: ((_ label: LWHyperLabel, _ string: String, _ range: NSRange) -> Void)?) {
        hashtagLinkTapHandler = handler
    }
    
    /**点击 LWHyperLabelTypeURL 类型回调*/
    func tapHandlerForURLLink(_ handler: ((_ label: LWHyperLabel, _ string: String, _ range: NSRange) -> Void)?) {
        urlLinkTapHandler = handler
    }
    
    /**点击 LWHyperLabelTypePhone 类型回调*/
    func tapHandlerForPhoneLink(_ handler: ((_ label: LWHyperLabel, _ string: String, _ range: NSRange) -> Void)?) {
        phoneLinkTapHandler = handler
    }
    
    /**点击 LWHyperLabelTypeAddress 类型回调*/
    func tapHandlerForAddressLink(_ handler: ((_ label: LWHyperLabel, _ string: String, _ range: NSRange) -> Void)?) {
        addressLinkTapHandler = handler
    }
    

}
