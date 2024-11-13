//
//  UIKView.swift
//  SmokeTest
//
//  Created by Arri Blais on 11/13/24.
//

import Foundation
import UIKit
import SwiftUI

struct UIKView: View {
    var body: some View {
        StoryboardViewControllerRepresentation()
    }
}

struct UIKView_preview: PreviewProvider {
    static var previews: some View {
        UIKView()
    }
}

struct StoryboardViewControllerRepresentation: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> some UIViewController {
        let storyboard = UIStoryboard(name: "UIKView", bundle: Bundle.main)
        let controller = storyboard.instantiateViewController(identifier: "UIKView")
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
    }
}

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }


}
