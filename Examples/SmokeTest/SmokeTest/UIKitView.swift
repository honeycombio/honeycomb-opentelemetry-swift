import Foundation
import SwiftUI
import UIKit

struct UIKitView: View {
    var body: some View {
        StoryboardViewControllerRepresentation()
    }
}

struct UIKView_preview: PreviewProvider {
    static var previews: some View {
        UIKitView()
    }
}

struct StoryboardViewControllerRepresentation: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> some UIViewController {
        let storyboard = UIStoryboard(name: "UIKitView", bundle: Bundle.main)
        let controller = storyboard.instantiateViewController(identifier: "UIKitView")
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
