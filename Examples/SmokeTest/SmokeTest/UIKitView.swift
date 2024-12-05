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
        let storyboard = UIStoryboard(name: "UIKitViewStoryboard", bundle: Bundle.main)
        let controller = storyboard.instantiateViewController(identifier: "UIKitNavigationRoot")
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
    }
}

class UIKitScreenViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "UIKit Screen"
        // Do any additional setup after loading the view.
    }

}

class UIKitMenuViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIKit Menu"
    }
}
