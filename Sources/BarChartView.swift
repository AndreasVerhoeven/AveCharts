//
//  BarChartView.swift
//  Demo
//
//  Created by Andreas Verhoeven on 13/09/2023.
//

import UIKit
import AutoLayoutConvenience
import AveDataSource
import AveFontHelpers
import AveCommonHelperViews
import UIKitAnimations

public protocol BarGraphItem: Identifiable {
	var id: ID { get }
	var title: String? { get }
	var value: Decimal { get }
}

public protocol BarGraphSection: Identifiable {
	associatedtype Item: BarGraphItem
	var id: ID { get }
	var title: String? { get }
	var items: [Item] { get }
}

public struct BarGraphViewSection<ItemID: Hashable, SectionID: Hashable>: BarGraphSection {
	public struct Item: BarGraphItem {
		public var id: ItemID
		public var title: String?
		public var value: Decimal
		
		public init(id: ItemID, title: String?, value: Decimal) {
			self.id = id
			self.title = title
			self.value = value
		}
	}
	
	public var id: SectionID
	public var title: String?
	public var items = [Item]()
	
	public init(id: SectionID, title: String? = nil, items: [Item] = []) {
		self.id = id
		self.title = title
		self.items = items
	}
}

open class BarGraphView<Section: BarGraphSection>: UIView, UICollectionViewDelegate {
	public let dashedLine = HorizontallyDashedLineView(frame: .zero)
	public let dashedLineLabel = UILabel(text: "", font: .fixed(size: 10), color: .secondaryLabel, alignment: .right, numberOfLines: 1).prefersExactSize()
	public let collectionView = UICollectionView(frame: .zero, collectionViewLayout: .init())
	
	open private(set) var maximumValue = Decimal.zero
	open private(set) var barColor = UIColor.systemBlue
	open private(set) var dashedLineValue: Decimal?
	
	open var shouldPinToEnd = true {
		didSet {
			isPinningToEnd = shouldPinToEnd
			setNeedsLayout()
		}
	}
	open private(set) var isPinningToEnd = true
	open private(set) var selection: FullIdentifier?
	open private(set) var values = [Section]()
	
	public typealias Section = Section
	public typealias SectionID = Section.ID
	public typealias Item = Section.Item
	public typealias ItemID = Section.Item.ID
	
	open var selectionDidChangeCallback: ((BarGraphView) -> Void)?
	
	open var selectedItem: Item? { selectedItemAndSection?.0 }
	open var lastItem: Item? { lastItemAndSection?.0 }
	
	open var selectedItemAndSection: (Section.Item, Section)? {
		guard let selection else { return nil }
		guard let section = values.first(where: { $0.id == selection.sectionId }) else { return nil }
		guard let item = section.items.first(where: { $0.id == selection.itemId }) else { return nil }
		return (item, section)
	}
	
	open var lastItemAndSection: (Section.Item, Section)? {
		guard let section = values.last else { return nil }
		guard let item = section.items.last else { return nil }
		return (item, section)
	}
	
	public struct FullIdentifier: Hashable {
		public var sectionId: SectionID
		public var itemId: ItemID
		
		public init(sectionId: SectionID, itemId: ItemID) {
			self.sectionId = sectionId
			self.itemId = itemId
		}
	}
	
	open func setSelection(sectionId: SectionID, itemId: ItemID, animated: Bool) {
		setSelection(FullIdentifier(sectionId: sectionId, itemId: itemId), animated: animated)
	}
	
	open func setSelection(_ selection: FullIdentifier?, animated: Bool) {
		guard self.selection != selection else { return }
		self.selection = selection
		dataSource.updateVisibleItems(animated: animated)
	}
	
	open func showDashedLine(at value: Decimal?, text: String?, animated: Bool) {
		if dashedLineValue != value {
			dashedLineValue = value
			UIView.performAnimationsIfNeeded(animated: animated) {
				self.dashedLine.alpha = value == nil ? 0 : 1
				self.dashedLineLabel.alpha = value == nil ? 0 : 1
			}
			updateDashedLinePosition(animated: animated)
			dataSource.updateVisibleItems(animated: animated)
		}
		dashedLineLabel.setText(text, animated: animated)
	}
	
	open func setValues(_ sections: [Section], barColor: UIColor? = nil, animated: Bool) {
		self.barColor = barColor ?? self.barColor
		self.values = sections
		
		var snapshot = Snapshot<Section, Item>()
		maximumValue = dashedLineValue ?? .zero
		for section in sections {
			snapshot.addItems(section.items, to: section)
			maximumValue = max(section.items.lazy.map(\.value).max() ?? .zero, maximumValue)
		}
		
		updateDashedLinePosition(animated: animated)
		dataSource.apply(snapshot, animated: animated)
	}
	
	// MARK: UICollectionViewDelegate
	public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		collectionView.deselectItem(at: indexPath, animated: true)
		let identifier = fullIdentifier(for: indexPath)
		
		if selection == identifier {
			selection = nil
		} else {
			selection = identifier
		}
		dataSource.updateVisibleItems(animated: true)
		selectionDidChangeCallback?(self)
	}
	
	// MARK: UIScrollViewDelegate
	public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
		isPinningToEnd = false
	}
	
	public func scrollViewDidScroll(_ scrollView: UIScrollView) {
		if shouldPinToEnd == true && collectionView.contentOffset.x >= endContentOffsetX {
			isPinningToEnd = true
		}
	}
	
	// MARK: - Privates
	private lazy var dataSource = CollectionViewDataSource<Section, Item>(collectionView: collectionView, cellsWithClass: Cell.self, updater: { [weak self] collectionView, cell, item, indexPath, animated in
		guard let self else { return }
		
		UIView.performAnimationsIfNeeded(animated: animated) { cell.barView.backgroundColor = self.barColor }
		cell.textLabel.setText(item.title, animated: animated)
		cell.setValue(item.value, maximumValue: maximumValue, animated: animated)
		cell.setShowFadedOut(self.shouldShowFadedOut(indexPath: indexPath), animated: animated)
	})
	
	private var endContentOffsetX: CGFloat {
		return collectionView.contentSize.width - collectionView.bounds.width + collectionView.contentInset.right
	}
	
	private var dashedLineConstraints: ConstraintsList!
	
	private func updateDashedLinePosition(animated: Bool) {
		let effectiveDashedLineValue = dashedLineValue ?? .zero
		var offset = CGFloat(24)
		if self.maximumValue != .zero {
			let percentage = max(0, min(effectiveDashedLineValue.cgFloatValue / maximumValue.cgFloatValue, 1))
			offset += percentage * (bounds.height - 24)
		}
		
		performLayoutUpdates(animated: animated) {
			self.dashedLineConstraints.bottom?.constant = offset
		}
	}
	
	func fullIdentifier(for indexPath: IndexPath) -> FullIdentifier {
		let section = dataSource.currentSnapshot.section(at: indexPath.section)
		let item = dataSource.currentSnapshot.item(at: indexPath)
		return FullIdentifier(sectionId: section.id, itemId: item.id)
	}
	
	func shouldShowFadedOut(indexPath: IndexPath) -> Bool {
		guard let selection else { return false }
		return fullIdentifier(for: indexPath) != selection
	}
	
	// MARK: - UIView
	public override init(frame: CGRect) {
		super.init(frame: frame)
		
		dashedLine.alpha = 0
		dashedLineLabel.alpha = 0
		dashedLineConstraints = addSubview(dashedLine, pinning: .centerY, to: .bottom, horizontally: .fill, insets: .bottom(12))
		addSubview(dashedLineLabel, fillingAtMost: .superview, insets: .trailing(8), pinning: .bottomTrailing, to: .topTrailing, of: .relative(dashedLine), offset: CGPoint(x: 0, y: -2))
		
		let stickyExtraTitleIdentifier = "StickyExtraTitle"
		dataSource.supplementaryElementViewProvider = { collectionView, section, indexPath, kind, animated in
			let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: stickyExtraTitleIdentifier, for: indexPath) as! StickyExtraTitleView
			view.textLabel.setText(section?.title, animated: animated)
			return view
		}
		
		let interItemSpacing = CGFloat(6)
		let itemWidth = CGFloat(22)
		let stickyFooterHeight = CGFloat(12)
		
		collectionView.delegate = self
		collectionView.register(Cell.self, forCellWithReuseIdentifier: "Cell")
		collectionView.register(StickyExtraTitleView.self, forSupplementaryViewOfKind: stickyExtraTitleIdentifier, withReuseIdentifier: stickyExtraTitleIdentifier)
		addSubview(collectionView, filling: .superview)
		
		let configuration = UICollectionViewCompositionalLayoutConfiguration()
		configuration.scrollDirection = .horizontal
		configuration.interSectionSpacing = interItemSpacing
		
		collectionView.contentInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 102)
		collectionView.collectionViewLayout = UICollectionViewCompositionalLayout(sectionProvider: { [weak self] section, environment in
			guard let self else { return nil }
			let size = NSCollectionLayoutSize(widthDimension: .absolute(itemWidth), heightDimension: .absolute(bounds.height - stickyFooterHeight))
			let item = NSCollectionLayoutItem(layoutSize: size)
			let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
			group.interItemSpacing = .fixed(interItemSpacing)
			
			let section = NSCollectionLayoutSection(group: group)
			section.interGroupSpacing = interItemSpacing
			
			let boundaryItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .estimated(20), heightDimension: .absolute(1)), elementKind: stickyExtraTitleIdentifier, alignment: .bottomLeading)
			boundaryItem.pinToVisibleBounds = true
			boundaryItem.extendsBoundary = false
			
			section.boundarySupplementaryItems = [boundaryItem]
			
			return section
		}, configuration: configuration)
		
		collectionView.backgroundColor = .clear
		collectionView.showsVerticalScrollIndicator = false
		collectionView.showsHorizontalScrollIndicator = false
		addSubview(collectionView, filling: .superview)
	}
	
	@available(*, unavailable)
	public required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	public override func layoutSubviews() {
		super.layoutSubviews()
		
		if shouldPinToEnd == true && isPinningToEnd == true {
			collectionView.contentOffset.x = endContentOffsetX
		}
	}
	
	public override var bounds: CGRect {
		didSet {
			guard bounds.height != oldValue.height else { return }
			updateDashedLinePosition(animated: false)
		}
	}
}

extension BarGraphView {
	public class HorizontallyDashedLineView: ShapeView {
		// MARK: - UIView
		public override init(frame: CGRect) {
			super.init(frame: frame)
			
			constrain(height: 1)
			fillColor = nil
			strokeColor = .secondaryLabel
			lineDashPhase = 12
			lineDashPattern = [8, 4]
			lineWidth = 1
		}
		
		@available(*, unavailable)
		public required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}
		
		public override func layoutSubviews() {
			super.layoutSubviews()
			let newPath = UIBezierPath()
			newPath.move(to: .zero)
			newPath.addLine(to: CGPoint(x: bounds.width, y: 0))
			path = newPath
		}
	}

	
	fileprivate class StickyExtraTitleView: UICollectionReusableView {
		let textLabel = UILabel(text: "", font: .fixed(size: 9), color: .secondaryLabel, numberOfLines: 1)
		
		override init(frame: CGRect) {
			super.init(frame: frame)
			
			addSubview(textLabel, pinning: .top, to: .bottom)
		}
		
		@available(*, unavailable)
		required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}
	}
	
	fileprivate class Cell: UICollectionViewCell {
		let wrapperView = UIView()
		let barView = RoundRectView(cornerRadius: 6, backgroundColor: .systemBlue, maskedCorners: .top, clipsToBounds: true)
		let textLabel = UILabel(text: "", font: .fixed(size: 9), color: .secondaryLabel, alignment: .center, numberOfLines: 1).constrain(height: 12)
		var heightConstraint: NSLayoutConstraint!
		
		private(set) var value = Decimal.zero
		private(set) var maximumValue = Decimal.zero
		
		private(set) var showFadedOut = false
		
		func setShowFadedOut(_ showFadedOut: Bool, animated: Bool) {
			guard self.showFadedOut != showFadedOut else { return }
			self.showFadedOut = showFadedOut
			
			UIView.performAnimationsIfNeeded(animated: animated) {
				self.wrapperView.alpha = showFadedOut ? 0.25: 1
			}
		}
		
		func setValue(_ value: Decimal, maximumValue: Decimal, animated: Bool) {
			guard self.value != value || self.maximumValue != maximumValue else { return }
			self.value = value
			self.maximumValue = maximumValue
			updateHeightConstraint(animated: animated)
		}
		
		// MARK: - Privates
		private func updateHeightConstraint(animated: Bool) {
			let percentage = maximumValue != .zero ? value.cgFloatValue / maximumValue.cgFloatValue : CGFloat(0.0)
			performLayoutUpdates(animated: animated) {
				self.heightConstraint.constant = max(1, CGFloat(percentage) * max(1, self.bounds.height - 12))
			}
		}
		
		// MARK: - UIView
		override var bounds: CGRect {
			didSet {
				guard oldValue.height != bounds.height else { return }
				updateHeightConstraint(animated: false)
			}
		}
		
		override init(frame: CGRect) {
			super.init(frame: frame)
			
			heightConstraint = barView.heightAnchor.constraint(equalToConstant: 2)
			heightConstraint.isActive = true
			wrapperView.addSubview(.verticallyStacked(barView, textLabel).vertically(aligned: .bottom), filling: .superview)
			contentView.addSubview(wrapperView, filling: .superview)
		}
		
		@available(*, unavailable)
		required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}
	}
}
