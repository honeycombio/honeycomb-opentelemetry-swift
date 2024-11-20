import SwiftUI

struct Park: Identifiable, Equatable, Hashable, Codable {
    let name: String
    var id: String {
        name
    }
}

extension Park {
    init?(from item: InstrumentedNavigationPathItem) {
        if let p: Park = item.boxedItem.unbox() {
            self = p
        }
        return nil
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
    // problems:
    // 1. writing a generic looking path is messy and _feels_ fragile
    // 2. the NavigationStack still thinks it's a strongly typed array
    //   so that means that the NavigationLink gets a concrete type
    //   and then navigationDestination defines a handler for the same concrete type
    //   but the NavigationStack doesn't see either of those, it sees the type-erased container!
    // 3. NavigationSplitView doesn't expose the same `path: $path` API! :sob: so users would need to track this manually _anyways_?

    //    @State private var presentedParks = AnyInstrumentedNavigationPath()
    @State private var presentedParks = InstrumentedNavigationPath<Park>()
    //      @State private var presentedParks: [Park] = []
    //  @State private var presentedParks = NavigationPath()

    var body: some View {
        NavigationStack(path: $presentedParks) {
            List(PARKS) { park in
                NavigationLink(park.name, value: park)
            }
            .navigationDestination(for: Park.self) { park in
                ParkDetails(park: park)
            }
            //            .navigationDestination(for: InstrumentedNavigationPathItem.self) { item in
            //                if let park = Park(from: item) {
            //                    ParkDetails(park: park)
            //                }
            //            }
        }
        .instrumentNavigations(path: presentedParks)
    }
}

typealias NestedItem = Equatable & Hashable & Encodable

protocol AnyBoxedPathItem {
    func unbox<T: NestedItem>() -> T?
    func isEqual(to other: AnyBoxedPathItem) -> Bool
    func hash(into hasher: inout Hasher)
    func encode(to encoder: Encoder) throws

    var _canonicalBoxed: AnyBoxedPathItem { get }
}

extension AnyBoxedPathItem {
    var _canonicalBoxed: AnyBoxedPathItem {
        return self
    }
}

struct InstrumentedNavigationPathItem: Equatable, Hashable, Encodable {
    static func == (lhs: InstrumentedNavigationPathItem, rhs: InstrumentedNavigationPathItem)
        -> Bool
    {
        return lhs.boxedItem.isEqual(to: rhs.boxedItem)
    }

    internal struct BoxedPathItem<Base: NestedItem>: AnyBoxedPathItem {
        internal var nested: Base

        init(_ nested: Base) {
            self.nested = nested
        }

        func hash(into hasher: inout Hasher) {
            nested.hash(into: &hasher)
        }

        func encode(to encoder: Encoder) throws {
            try nested.encode(to: encoder)
        }

        func unbox<T>() -> T? where T: NestedItem {
            (self as AnyBoxedPathItem as? BoxedPathItem<T>)?.nested
        }

        func isEqual(to other: AnyBoxedPathItem) -> Bool {
            if let rhs: Base = other.unbox() {
                return nested == rhs
            }
            return false
        }
    }

    let boxedItem: AnyBoxedPathItem

    init<T: NestedItem>(_ nestedHashable: T) {
        self.boxedItem = BoxedPathItem(nestedHashable)
    }

    func hash(into hasher: inout Hasher) {
        self.boxedItem._canonicalBoxed.hash(into: &hasher)
    }

    func encode(to encoder: Encoder) throws {
        try boxedItem._canonicalBoxed.encode(to: encoder)
    }
}

class AnyInstrumentedNavigationPath: MutableCollection, RandomAccessCollection,
    RangeReplaceableCollection, Encodable
{
    typealias Element = InstrumentedNavigationPathItem
    typealias Index = Int
    typealias SubSequence = Slice<AnyInstrumentedNavigationPath>

    private var data: [InstrumentedNavigationPathItem]

    required init() {
        self.data = []
        encodePath()
    }

    init(data: [InstrumentedNavigationPathItem]) {
        self.data = data
        encodePath()
    }

    var startIndex: Int { data.startIndex }
    var endIndex: Int { data.endIndex }

    subscript(index: Index) -> Iterator.Element {
        get {
            return data[index]
        }
        set {
            // TODO this looks like it's adding things twice?
            print("setter")
            data[index] = newValue
            encodePath()
        }
    }

    // Method that returns the next index when iterating
    func index(after i: Index) -> Index {
        return data.index(after: i)
    }

    func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C)
    where C: Collection, Element == C.Element {
        print("replace")
        data.replaceSubrange(subrange, with: newElements)
        encodePath()
    }

    private func encodePath() {
        print(data)
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(data)
            print("current path: \(String(decoding: data, as: UTF8.self))")
        } catch {
            // Handle error.
        }
    }
}

class InstrumentedNavigationPath<Element>: MutableCollection, RandomAccessCollection,
    RangeReplaceableCollection,
    Encodable
where Element: Hashable, Element: Encodable {
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

    var startIndex: Int {
        return data.startIndex
    }
    var endIndex: Int {
        return data.endIndex
    }

    subscript(index: Index) -> Iterator.Element {
        get {
            return data[index]
        }
        set {
            data[index] = newValue
            encodePath()
        }
    }

    // Method that returns the next index when iterating
    func index(after i: Index) -> Index {
        return data.index(after: i)
    }

    func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C)
    where C: Collection, Element == C.Element {
        data.replaceSubrange(subrange, with: newElements)
        encodePath()
    }

    private func encodePath() {
        print(data)
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

    func instrumentNavigations(path: Encodable) -> some View {
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
