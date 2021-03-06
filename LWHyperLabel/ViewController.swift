//
//  ViewController.swift
//  LWHyperLabel
//
//  Created by 赖灵伟 on 16/4/27.
//  Copyright © 2016年 lailingwei. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var linkLabel: LWHyperLabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        // 设置超链接颜色（默认为蓝色）
        linkLabel.tintColor = UIColor.purple
        
        // 设置超链接的选中背景颜色（默认浅白色）
        linkLabel.selectedLinkBgColor = UIColor.white.withAlphaComponent(0.95)
        
        // 是否自动检测超链接（默认开启）
        linkLabel.autoLinkDetectionEnabled = true
        
        // 设置检测的超链接类型（默认全部开启）
        linkLabel.linkDetectionTypes = [
            LWHyperLabelType.userHandle,
            LWHyperLabelType.hashtag,
            LWHyperLabelType.url,
            LWHyperLabelType.phone,
            LWHyperLabelType.address]
        
        // 设置屏蔽的关键字
        linkLabel.ignoredKeywords = NSSet(array: ["@llw订单"])
        
        
        // 主要记得勾上userInteractionEnabled
        /*
         /**点击 LWHyperLabelTypeUserHandle 类型回调*/
         internal var userHandleLinkTapHandler: ((label: LWLinkLabel, string: String, range: NSRange) -> Void)?
         
         /**点击 LWHyperLabelTypeHashtag 类型回调*/
         internal var hashtagLinkTapHandler: ((label: LWLinkLabel, string: String, range: NSRange) -> Void)?
         
         /**点击 LWHyperLabelTypeURL 类型回调*/
         internal var urlLinkTapHandler: ((label: LWLinkLabel, string: String, range: NSRange) -> Void)?
         
         /**点击 LWHyperLabelTypePhone 类型回调*/
         internal var phoneLinkTapHandler: ((label: LWLinkLabel, string: String, range: NSRange) -> Void)?
         
         /**点击 LWHyperLabelTypeAddress 类型回调*/
         internal var addressLinkTapHandler: ((label: LWLinkLabel, string: String, range: NSRange) -> Void)?
         */
        linkLabel.tapHandlerForUserHandleLink { (label, string, range) -> Void in
            print(string)
        }
        linkLabel.tapHandlerForHashtagLink { (label, string, range) -> Void in
            print(string)
        }
        linkLabel.tapHandlerForURLLink { (label, string, range) -> Void in
            print(string)
        }
        linkLabel.tapHandlerForPhoneLink { (label, string, range) -> Void in
            print(string)
        }
        linkLabel.tapHandlerForAddressLink { (label, string, range) -> Void in
            print(string)
        }

        
        
    }



}

