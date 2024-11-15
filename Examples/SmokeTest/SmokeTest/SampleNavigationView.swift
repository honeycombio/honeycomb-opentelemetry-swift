import SwiftUI

struct Park: Identifiable, Hashable, Codable {
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
    @State private var presentedParks = NavigationPath()

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

extension View {
    func instrumentNavigations(path: NavigationPath) -> some View {
        guard let representation = path.codable else {
            return modifier(EmptyModifier())
        }
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(representation)
            print("current path: \(String(decoding: data, as: UTF8.self))")
        } catch {
            // Handle error.
        }

        return modifier(EmptyModifier())
    }

    func instrumentNavigations(path: [some Encodable]) -> some View {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(path)
            print("current path: \(String(decoding: data, as: UTF8.self))")
        } catch {
            // Handle error
        }

        return modifier(EmptyModifier())
    }
}

#Preview {
    SampleNavigationView()
}
