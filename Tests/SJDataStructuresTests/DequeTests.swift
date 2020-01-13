import XCTest
import SJDataStructures

final class DequeTests: XCTestCase {
    func testExponentialGrowthInt() {
        func test<Element>(
            file: StaticString = #file,
            line: UInt = #line,
            appending element: Element,
            expectedCapacities: Int...
        ) {
            var deque = Deque<Element>()
            XCTAssertEqual(deque.capacity, 0, file: file, line: line)
            var actualCapacities = [Int]()
            for _ in 0 ..< expectedCapacities.count {
                deque.append(element)
                actualCapacities.append(deque.capacity)
            }
            XCTAssertEqual(expectedCapacities, actualCapacities, file: file, line: line)
        }

        if is32BitPlatform() {
            test(appending: 0 as Int,
                 expectedCapacities: 8, 8, 8, 8, 8, 8, 8, 8, 16)

            test(appending: 0 as Int8,
                 expectedCapacities: 64, 64, 64, 64, 64, 64, 64, 64, 64)

            test(appending: 0 as Int16,
                 expectedCapacities: 32, 32, 32, 32, 32, 32, 32, 32, 32)

            test(appending: 0 as Int32,
                 expectedCapacities: 16, 16, 16, 16, 16, 16, 16, 16, 16)

            test(appending: 0 as Int64,
                 expectedCapacities: 8, 8, 8, 8, 8, 8, 8, 8, 16)

            test(appending: (0, 0, 0, 0) as (UInt64, UInt64, UInt64, UInt64),
                 expectedCapacities: 2, 2, 4, 4, 8, 8, 8, 8, 16)
        } else {
            test(appending: 0 as Int,
                 expectedCapacities: 2, 2, 4, 4, 8, 8, 8, 8, 16)

            test(appending: 0 as Int8,
                 expectedCapacities: 16, 16, 16, 16, 16, 16, 16, 16, 16)

            test(appending: 0 as Int16,
                 expectedCapacities: 8, 8, 8, 8, 8, 8, 8, 8, 16)

            test(appending: 0 as Int32,
                 expectedCapacities: 4, 4, 4, 4, 8, 8, 8, 8, 16)

            test(appending: 0 as Int64,
                 expectedCapacities: 2, 2, 4, 4, 8, 8, 8, 8, 16)

            test(appending: (0, 0, 0, 0) as (UInt64, UInt64, UInt64, UInt64),
                 expectedCapacities: 1, 2, 4, 4, 8, 8, 8, 8, 16)
        }
    }

    func testInitFromArrayLiteral() {
        let deque: Deque = [1, 2, 3, 4, 5]
        XCTAssertEqual(deque.capacity, is32BitPlatform() ? 8 : 5)
    }

    func testAppendArray() {
        var deque: Deque = [1, 2, 3]
        deque.append(contentsOf: [4, 5, 6, 7, 8, 9, 10])
        XCTAssertEqual(Array(deque), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    }

    func testAppendEmptyCollectionToEmptyDeque() {
        var deque = Deque<Int>()
        deque.append(contentsOf: EmptyCollection())
        XCTAssert(deque.isEmpty)
        XCTAssertEqual(Array(deque), [])
    }

    func testAppendEmptyCollectionToNonEmptyDeque() {
        var deque: Deque = [1, 2, 3]
        deque.append(contentsOf: EmptyCollection())
        XCTAssertEqual(Array(deque), [1, 2, 3])
    }

    func testAppendUnderestimatedSequenceToEmptyDeque() {
        var deque = Deque<Int>()
        deque.append(contentsOf: UpTo10UnderestimatedSequence())
        XCTAssertEqual(Array(deque), [1, 2, 3, 4, 5, 6, 7, 8, 9])
    }

    func testAppendUnderestimatedSequenceToNonEmptyDeque() {
        var deque: Deque = [1, 2, 3]
        deque.append(contentsOf: UpTo10UnderestimatedSequence())
        XCTAssertEqual(Array(deque), [1, 2, 3, 1, 2, 3, 4, 5, 6, 7, 8, 9])
    }
}

private func is32BitPlatform() -> Bool { Int.bitWidth == 32 }

final class UpTo10UnderestimatedSequence: Sequence, IteratorProtocol {

    var counter = 0

    func next() -> Int? {
        counter += 1
        if counter == 10 { return nil }
        return counter
    }

    let underestimatedCount: Int = 5
}
