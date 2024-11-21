import SwiftUI

@testable import Honeycomb

struct Park: Identifiable, Equatable, Hashable, Codable {
    let name: String
    var id: String {
        name
    }
}

let PARKS = [
    Park(name: "Yosemite"),
    Park(name: "Zion"),
]

struct ParkDetails: View {
    let park: Park
    var body: some View {
        Text("details for \(park.name)")
    }
}

struct SampleNavigationView: View {
    @State private var presentedParks: [Park] = []
    //  @State private var presentedParks = NavigationPath()

    var body: some View {
        NavigationStack(path: $presentedParks) {
            List(PARKS) { park in
                NavigationLink(park.name, value: park)
            }
            .navigationDestination(for: Park.self) { park in
                ParkDetails(park: park)
            }
        }
        .instrumentNavigations(path: presentedParks)
    }
}

#Preview {
    SampleNavigationView()
}
