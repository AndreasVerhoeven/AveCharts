//
//  ViewController.swift
//  Demo
//
//  Created by Andreas Verhoeven on 16/05/2021.
//

import UIKit
import AutoLayoutConvenience

class ViewController: UIViewController {
	
	let chart = StringPieChartView().constrain(widthAndHeight: 300)
	
	@objc private func bla(_ sender: Any) {
		if(chart.items.count != 4) {
			restore(animated: true)
		} else {
			magic(animated: true)
		}
	}
	
	func magic(animated: Bool) {
		let items: [StringPieChartView.Item] = [
			.init(id: "A", color: .red, value: 20),
			//.init(id: "B", color: .green, value: 10),
			//.init(id: "C", color: .blue, value: 10),
			//.init(id: "D", color: .yellow, value: 20),
		]
		chart.setItems(items, animated: animated)
	}
	
	func restore(animated: Bool) {
		let items: [StringPieChartView.Item] = [
			.init(id: "A", color: .red, value: 10),
			.init(id: "B", color: .green, value: 10),
			.init(id: "C", color: .blue, value: 10),
			.init(id: "D", color: .yellow, value: 10),
		]
		chart.setItems(items, animated: animated)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		
		view.backgroundColor = .systemBackground
		view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(bla(_:))))
		
		restore(animated: false)
		view.addSubview(chart, centeredIn: .safeArea)
	}
}

