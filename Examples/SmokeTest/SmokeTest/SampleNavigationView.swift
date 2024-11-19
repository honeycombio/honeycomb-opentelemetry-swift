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

func getData<Data>(x: Data) where Data : MutableCollection, Data : RandomAccessCollection, Data : RangeReplaceableCollection, Data.Element : Hashable {
    // do the thing
}

struct SampleNavigationView: View {
    @State private var presentedParks = InstrumentedNavigationPath<Park>()

    var body: some View {
        NavigationStack(path: $presentedParks) {
            List(PARKS) { park in
                NavigationLink(park.name, value: park)
            }
            .navigationDestination(for: Park.self) { park in
                ParkDetails(park: park)
            }
        }
    }
}

protocol InstrumentedNavigationPathItem : Hashable, Encodable {}

class InstrumentedNavigationPath<Element>: MutableCollection, RandomAccessCollection, RangeReplaceableCollection where Element : Hashable, Element: Encodable {
    typealias Element = Element
    typealias Index = Int
    typealias SubSequence = Slice<InstrumentedNavigationPath>
    
    private var data: [Element]
    
    required init() {
        self.data = []
        encodePath()
    }
    
    init(data: [Element]) {
        self.data = data
        encodePath()
    }

    var startIndex: Int { data.startIndex }
    var endIndex: Int { data.endIndex }
    
    subscript(index: Index) -> Iterator.Element {
        get { return data[index] }
        set {
            data[index] = newValue
            encodePath()
        }
    }

    // Method that returns the next index when iterating
    func index(after i: Index) -> Index {
        return data.index(after: i)
    }
    
    func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C : Collection, Element == C.Element {
        data.replaceSubrange(subrange, with: newElements)
        encodePath()
    }
    
    private func encodePath() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(data)
            print("current path: \(String(decoding: data, as: UTF8.self))")
        } catch {
            // Handle error.
        }
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
