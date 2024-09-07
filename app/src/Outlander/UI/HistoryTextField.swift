//
//  HistoryTextField.swift
//  Outlander
//
//  Created by Joseph McBride on 12/13/19.
//  Copyright © 2019 Joe McBride. All rights reserved.
//

import AppKit
import Cocoa
import Foundation

public class HistoryTextField: NSTextField {
    var currentHistoryIndex = -1

    public var history: [String] = []
    public var maxHistory = 30
    public var minCharacterLength = 3

    public var executeCommand: (String) -> Void = { _ in }

    @IBInspectable
    public var progress: Double = 0.0 {
        didSet {
            needsDisplay = true
        }
    }

    @IBInspectable
    public var progressColor = NSColor(hex: "#003366")! {
        didSet {
            needsDisplay = true
        }
    }

    @IBInspectable
    public var promptBackgroundColor = NSColor(hex: "#003366")! {
        didSet {
            needsDisplay = true
        }
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        focusRingType = .none
        drawsBackground = false
        isBezeled = false
    }

    override public func becomeFirstResponder() -> Bool {
        let textView = window?.fieldEditor(true, for: nil) as? NSTextView
        textView?.insertionPointColor = textColor ?? NSColor.white
        return super.becomeFirstResponder()
    }

    func hasFocus() -> Bool {
        let res = window?.firstResponder?.isKind(of: NSTextView.self) == true
            && window?.fieldEditor(false, for: nil) != nil
            && (window?.firstResponder == self)
        return res == true
    }

    override public func draw(_ dirtyRect: NSRect) {
        let fullRect = bounds
        promptBackgroundColor.setFill()
        fullRect.fill(using: .sourceOver)

        print(promptBackgroundColor.getHexString())

        var progressRect = bounds
        progressRect.size.width *= CGFloat(progress)

        progressColor.setFill()
        progressRect.fill(using: .sourceOver)

        super.draw(dirtyRect)
    }

    enum KeyCodes: UInt16 {
        case home = 115
        case end = 119
        case up = 126
        case down = 125
    }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        let key = KeyCodes(rawValue: event.keyCode)

        switch key {
        case .up:
            previous()
            return true
        case .down:
            next()
            return true
        case .home:
            selectText(self)
            currentEditor()?.selectedRange = NSMakeRange(0, 0)
            return true
        case .end:
            selectText(self)
            currentEditor()?.selectedRange = NSMakeRange(stringValue.count, 0)
            return true
        default:
            break
        }

        return super.performKeyEquivalent(with: event)
    }

    func commitHistory() {
        currentHistoryIndex = -1

        var value = stringValue
        stringValue = ""

        if value.count == 0 {
            value = history.first ?? ""
        }

        if value.count > 0 {
            executeCommand(value)
        }

        if value.count < minCharacterLength || value == history.first { return }

        history.insert(value, at: 0)

        if history.count > maxHistory {
            history.removeLast()
        }
    }

    func previous() {
        var value = ""

        currentHistoryIndex += 1

        if currentHistoryIndex > -1 {
            if currentHistoryIndex >= history.count {
                currentHistoryIndex = -1
            } else {
                value = history[currentHistoryIndex]
            }
        }

        stringValue = value

        DispatchQueue.main.async {
            self.currentEditor()?.moveToEndOfDocument(nil)
        }
    }

    func next() {
        var value = ""
        let lastIndex = currentHistoryIndex

        if lastIndex == -1 {
            currentHistoryIndex = history.count
        }

        currentHistoryIndex -= 1

        if currentHistoryIndex > -1 {
            if lastIndex == 0 {
                currentHistoryIndex = -1
            } else {
                value = history[currentHistoryIndex]
            }
        }

        stringValue = value

        DispatchQueue.main.async {
            self.currentEditor()?.moveToEndOfDocument(nil)
        }
    }
}

class VerticallyAlignedTextFieldCell: NSTextFieldCell {
    open func adjustedFrame(toVerticallyCenterText rect: NSRect) -> NSRect {
        // super would normally draw text at the top of the cell
        var titleRect = super.titleRect(forBounds: rect)

        let cellSize = cellSize(forBounds: rect)

        titleRect.origin.y += (titleRect.height - cellSize.height) / 2
        titleRect.size.height = cellSize.height

        return titleRect
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: adjustedFrame(toVerticallyCenterText: rect), in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: adjustedFrame(toVerticallyCenterText: rect), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        super.drawInterior(withFrame: adjustedFrame(toVerticallyCenterText: cellFrame), in: controlView)
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        super.draw(withFrame: cellFrame, in: controlView)
    }
}

class PaddingTextFieldCell: VerticallyAlignedTextFieldCell {
    private static let padding = CGSize(width: 15.0, height: 5.0)

    override func cellSize(forBounds rect: NSRect) -> NSSize {
        var size = super.cellSize(forBounds: rect)
        size.height += (PaddingTextFieldCell.padding.height * 2)
        size.width += PaddingTextFieldCell.padding.width
        return size
    }

    override func adjustedFrame(toVerticallyCenterText rect: NSRect) -> NSRect {
        let cellSize = cellSize(forBounds: rect)
        var adjRect = super.adjustedFrame(toVerticallyCenterText: rect)
        adjRect.origin.x += (adjRect.width - cellSize.width) / 2
        return adjRect
    }

//    override func titleRect(forBounds rect: NSRect) -> NSRect {
//        var rect = super.titleRect(forBounds: rect)
//        return rect
    ////        return rect.insetBy(dx: PaddingTextFieldCell.padding.width, dy: PaddingTextFieldCell.padding.height)
//    }
//
//    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
    ////        let insetRect = rect.insetBy(dx: PaddingTextFieldCell.padding.width, dy: PaddingTextFieldCell.padding.height)
//        var insetRect = rect
//        super.edit(withFrame: insetRect, in: controlView, editor: textObj, delegate: delegate, event: event)
//    }
//
//    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
    ////        let insetRect = rect.insetBy(dx: PaddingTextFieldCell.padding.width, dy: PaddingTextFieldCell.padding.height)
//        var insetRect = rect
//        super.select(withFrame: insetRect, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
//    }
//
//    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
    ////        let insetRect = cellFrame.insetBy(dx: PaddingTextFieldCell.padding.width, dy: PaddingTextFieldCell.padding.height)
//        var insetRect = cellFrame
//        super.drawInterior(withFrame: insetRect, in: controlView)
//    }
}
