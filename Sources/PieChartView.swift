//
//  PieChartView.swift
//  BDemo
//
//  Created by Andreas Verhoeven on 03/07/2022.
//

import UIKit
import AveCommonHelperViews
import AutoLayoutConvenience
import AveDataSource
import GeometryHelpers
import UIKitAnimations

public protocol PieChartItem: Identifiable, Hashable {
	var id: ID { get }
	var color: UIColor { get }
	var value: Decimal { get }
}


open class PieChartView<Item: PieChartItem>: UIView {
	public struct Item<ID: Hashable>: PieChartItem {
		public var id: ID
		public var color: UIColor
		public var value: Decimal
	}
	
	private(set) open var items = [Item]()
	private var sliceViews = [SliceView]()
	private var isPendingDeletionSliceViews = Set<SliceView>()
	
	private(set) open var selectedItemIds = Set<Item.ID>()
	open var singleSelectedItemId: Item.ID? { selectedItemIds.first }
	
	open var selectionCallback: ((Item.ID?) -> Void)?
	
	public struct SelectionStyle: OptionSet, RawRepresentable {
		public var rawValue: Int
		
		public init(rawValue: Int) { self.rawValue = rawValue }
		
		public static var moveOutSelected: Self {  Self(rawValue: 1 << 0) }
		public static var shadowSelected: Self { Self(rawValue: 1 << 1) }
		public static var fadeOutUnselected: Self { Self(rawValue: 1 << 2) }
			
		public static var defaults: Self { [.moveOutSelected, .shadowSelected, .fadeOutUnselected] }
	}
		
	open var selectionStyle: SelectionStyle = .defaults {
		didSet {
			guard selectionStyle != oldValue else { return }
			updateSelection(animated: false)
		}
	}
	
	public override init(frame: CGRect = .zero) {
		super.init(frame: frame)
		setup()
	}
	
	public required init?(coder: NSCoder) {
		super.init(coder: coder)
		setup()
	}
	
	open func setSelectedItemIds<T: Sequence>(_ ids: T, animated: Bool) where T.Element == Item.ID {
		let newSet = Set(ids)
		guard newSet != selectedItemIds else { return }
		selectedItemIds = newSet
		updateSelection(animated: true)
	}
	
	open func setSingleSelectedItemId(_ id: Item.ID?, animated: Bool) {
		setSelectedItemIds(id.flatMap({ Set([$0]) }) ?? Set(), animated: animated)
	}
	
	open func setItems(_ newItems: [Item], animated: Bool) {
		guard items != newItems else { return }
		
		var newViews = sliceViews
		var deletionIndices = Set<Int>()
		
		let diff = newItems.difference(from: items) { $0.id == $1.id }
		for diffItem in diff.insertions {
			switch diffItem {
				case .insert(let offset, let item, _):
					let newView = SliceView(initial: offset > 0 ? newViews[offset - 1].endAngle : 0, color: item.color)
					newView.setShadow(color: UIColor.black.cgColor, opacity: 0, radius: 2, offset: CGSize(width: 0, height: 1))
					newView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
					addSubview(newView, filling: .superview)
					newViews.insert(newView, at: offset)
					
				case .remove(let offset, _, _):
					deletionIndices.insert(offset)
			}
			
		}
		
		items = newItems
		sliceViews = newViews
		let isPendingDeletionSliceViews: Set<SliceView> = Set<SliceView>( deletionIndices.map({ newViews[$0] }))

		//UIView.performAnimationsIfNeeded(animated: animated, animations: {
		UIView.animate(withDuration: 1, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
			var start = CGFloat(0)
			let total = self.items.lazy.map(\.value).reduce(Decimal.zero, +).cgFloatValue
			for (view, item) in zip(self.sliceViews, self.items) {
				if isPendingDeletionSliceViews.contains(view) == true {
					view.setStartAngle(start, end: start)
				} else {
					let percentage = total != 0 ? item.value.cgFloatValue / total : 0
					let end = start + 2 * .pi * percentage
					view.setStartAngle(start, end: end)
					view.color = item.color
					start = end
				}
				self.updateSelection(for: item, sliceView: view, animated: animated)
			}
			
		}, completion: { _ in
			isPendingDeletionSliceViews.forEach { $0.removeFromSuperview() }
			self.sliceViews.removeAll { isPendingDeletionSliceViews.contains($0) }
		})
	}
	
	// MARK: - Input
	@objc private func tapped(_ sender: UITapGestureRecognizer) {
		if let sliceView = sender.view as? SliceView, isPendingDeletionSliceViews.contains(sliceView) == false, let index = sliceViews.firstIndex(of: sliceView) {
			selectionCallback?(items[index].id)
		} else {
			selectionCallback?(nil)
		}
	}
	
	// MARK: - Privates
	private func updateSelection(animated: Bool) {
		for (item, sliceView) in zip(self.items, self.sliceViews) {
			updateSelection(for: item, sliceView: sliceView, animated: animated)
		}
	}
	
	private func updateSelection(for item: Item, sliceView: SliceView, animated: Bool) {
		let isSelected = selectedItemIds.contains(item.id) == true && isPendingDeletionSliceViews.contains(sliceView) == false
		
		UIView.performAnimationsIfNeeded(animated: animated, duration: 0.3) {
			sliceView.alpha = (self.selectedItemIds.isEmpty == false && self.selectionStyle.contains(.fadeOutUnselected) == true && isSelected == false) ? 0.2 : 1
			
			sliceView.layer.shadowOpacity = (self.selectionStyle.contains(.shadowSelected) == true && isSelected == true) ? 1 : 0
		}
		
		let updates = {
			sliceView.transform = (self.selectionStyle.contains(.moveOutSelected) == true && isSelected == true) ? sliceView.transformForSelection : .identity
		}
		
		if animated == true {
			if isSelected == true {
				UIView.animate(withDuration: 1.5, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 10, options: [.beginFromCurrentState, .allowUserInteraction], animations: updates)
			} else {
				UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: updates)
			}
		} else {
			updates()
		}
	}
	
	private func setup() {
		addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
		selectionCallback = { [weak self] id in self?.setSingleSelectedItemId(self?.singleSelectedItemId == id ? nil : id, animated: true) }
	}
}


extension PieChartView {
	class SliceView: ShapeView {
		var radius: CGFloat { min(bounds.width * 0.5, bounds.height * 0.5) }
		var circleCenter: CGPoint { bounds.center }
		
		var startAngle: CGFloat {
			get { sliceLayer.startAngle }
			set { sliceLayer.startAngle = newValue }
		}
		
		var endAngle: CGFloat {
			get { sliceLayer.endAngle }
			set { sliceLayer.endAngle = newValue }
		}
		
		convenience init(initial: CGFloat = 0, color: UIColor?) {
			self.init(frame: .zero)
			setStartAngle(initial, end: initial)
			_ = { self.color = color }()
		}
		
		var color: UIColor? {
			get { fillColor }
			set {
				fillColor = newValue
				strokeColor = newValue?.blended(with: .systemBackground.alwaysDark.withAlphaComponent(0.25))
				
				//newValue.flatMap { UIColor.systemBackground.withAlphaComponent(0.5).blended(with: $0) }
			}
		}
		
		var transformForSelection: CGAffineTransform {
			let mid = startAngle + (endAngle - startAngle) * 0.5
			func point(for radius: CGFloat) -> CGPoint {
				return UIBezierPath(arcCenter: bounds.center, radius: radius, startAngle: mid, endAngle: mid, clockwise: true).currentPoint
			}
			
			return CGAffineTransform(from: point(for: radius), to: point(for: radius + 16))
		}
		
		func setStartAngle(_ start: CGFloat, end: CGFloat) {
			guard start != self.startAngle || end != self.endAngle else { return }
			self.startAngle = start
			self.endAngle = end
		}
		
		override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
			guard let hit = super.hitTest(point, with: event) else { return nil }
			guard hit === self else { return hit }
			return sliceLayer.path?.contains(point) == true ? hit : nil
		}
		
		override class var layerClass: AnyClass { Layer.self }
		
		// MARK: - CALayerDelegate
		override open func action(for layer: CALayer, forKey key: String) -> CAAction? {
			if key == "startAngle" || key == "endAngle" {
				if let animation = layer.action(forKey: "opacity") as? CABasicAnimation {
					animation.keyPath = key
					animation.fromValue = (layer.presentation() ?? layer).value(forKey: key)
					animation.toValue = nil
					animation.byValue = nil
					return animation
				}
			}
			
			return super.action(for: layer, forKey: key)
		}
		
		// MARK: - Privates
		private var sliceLayer: Layer { layer as! Layer }
	}
}

extension PieChartView.SliceView {
	class Layer: CAShapeLayer {
		@objc @NSManaged dynamic var startAngle: CGFloat
		@objc @NSManaged dynamic var endAngle: CGFloat
		
		override class func needsDisplay(forKey key: String) -> Bool {
			return super.needsDisplay(forKey: key) || key == #keyPath(startAngle) || key == #keyPath(endAngle)
		}
		
		override func display() {
			super.display()
			
			let startAngle = (self.presentation() ?? self).startAngle
			let endAngle = max(startAngle, (self.presentation() ?? self).endAngle)
			
			let path = UIBezierPath()
			let circle = Circle(in: bounds)
			path.move(to: circle.center)
			path.addArc(withCenter: circle.center, radius: circle.radius, startAngle: startAngle, endAngle: startAngle, clockwise: true)
			path.addArc(withCenter: circle.center, radius: circle.radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
			path.addLine(to: circle.center)
			
			self.path = path.cgPath
		}
		
		override init() {
			super.init()
			needsDisplayOnBoundsChange = true
		}
		
		override init(layer: Any) {
			super.init(layer: layer)
			
			guard let layer = layer as? Layer else { return }
			self.startAngle = layer.startAngle
			self.endAngle = layer.endAngle
			self.needsDisplayOnBoundsChange = layer.needsDisplayOnBoundsChange
		}
		
		
		required init?(coder: NSCoder) {
			super.init(coder: coder)
		}
	}
}

extension CGFloat {
	init(_ decimal: Decimal) {
		self.init((decimal as NSDecimalNumber).doubleValue)
	}
}

extension Decimal {
	var cgFloatValue: CGFloat { CGFloat(self) }
}
