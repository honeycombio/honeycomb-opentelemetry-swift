import Honeycomb
import SwiftUI

// MARK: data models
struct Park: Identifiable, Equatable, Hashable, Codable {
    let name: String
    var id: String {
        name
    }
}

let parks = [
    Park(name: "Yosemite"),
    Park(name: "Zion"),
]

func park(from id: Park.ID?) -> Park? {
    if let parkId = id {
        if let index = parks.firstIndex(where: { $0.id == parkId }) {
            return parks[index]
        }
    }
    return nil
}

struct Tree: Identifiable, Equatable, Hashable, Codable {
    let name: String
    var id: String {
        name
    }
}

let trees = [
    Tree(name: "Oak Tree"),
    Tree(name: "Maple Tree"),
]

func tree(from id: Tree.ID?) -> Tree? {
    if let treeId = id {
        if let index = trees.firstIndex(where: { $0.id == treeId }) {
            return trees[index]
        }
    }
    return nil
}

// MARK: views
struct ParkDetails: SwiftUI.View {
    let park: Park
    var body: some SwiftUI.View {
        Text("details for \(park.name)")
    }
}

struct TreeDetails: SwiftUI.View {
    let park: Park
    let tree: Tree
    var body: some SwiftUI.View {
        Text("\(park) has many \(tree)")
    }
}

struct NavigationStackExample: SwiftUI.View {
    @State private var presentedParks = NavigationPath()
    @State private var usePrefix = false

    var body: some SwiftUI.View {
        Toggle("Include path prefix", isOn: $usePrefix)
        NavigationStack(path: $presentedParks) {
            List(parks) { park in
                NavigationLink(park.name, value: park)
            }
            .navigationDestination(for: Park.self) { park in
                ParkDetails(park: park)
            }
        }
        .instrumentNavigation(
            prefix: usePrefix ? "NavigationStackRoot" : nil,
            path: presentedParks,
            reason: "visiting parks list"
        )
    }
}

let navigationSplitExampleRoot = "Split View Parks Root"
struct NavigationSplitExample: SwiftUI.View {
    @State private var selectedPark: Park.ID? = nil
    @State private var selectedTree: Park.ID? = nil

    var body: some SwiftUI.View {
        NavigationSplitView {
            List(parks, selection: $selectedPark) { park in
                Text(park.name)
            }
            .onAppear {
                Honeycomb.setCurrentScreen(path: navigationSplitExampleRoot)
            }
        } content: {
            if let park = park(from: selectedPark) {
                ParkDetails(park: park)
                    .onAppear {
                        let path: [Encodable] = [navigationSplitExampleRoot, park]
                        Honeycomb.setCurrentScreen(path: path, reason: "visiting \(park)")
                    }
                List(trees, selection: $selectedTree) { tree in
                    Text(tree.name)
                }
            } else {
                Text("Select a park")
            }
        } detail: {
            if let park = park(from: selectedPark), let tree = tree(from: selectedTree) {
                TreeDetails(park: park, tree: tree)
                    .onAppear {
                        let path: [Encodable] = [navigationSplitExampleRoot, park, tree]
                        Honeycomb.setCurrentScreen(path: path)
                    }
            } else {
                Text("Select a tree")
            }
        }
    }
}

struct NavigationExamplesView: SwiftUI.View {
    @State private var useSplit = false

    var body: some SwiftUI.View {
        VStack {
            Toggle("Use Split View", isOn: $useSplit)
            if useSplit {
                NavigationSplitExample()
            } else {
                NavigationStackExample()
            }
        }
    }
}

#Preview {
    NavigationExamplesView()
}
