@usableFromInline
internal struct DequeBufferHeader {

    /// The first element is stored at this index
    @usableFromInline
    var start: Int

    @usableFromInline
    var count: Int

    @usableFromInline
    var capacity: Int

    @inlinable
    init(start: Int, count: Int, capacity: Int) {
        self.start = start
        self.count = count
        self.capacity = capacity
    }

    @inlinable
    var leftSideCount: Int { count &- rightSideCount }

    @inlinable
    var rightSideCount: Int { min(count, capacity &- start) }

    @inlinable
    func position(for index: Int) -> Int { (start &+ index) % capacity }
}

@usableFromInline
internal final class DequeBuffer<Element>: ManagedBuffer<DequeBufferHeader, Element> {

    @inlinable
    static func create(minimumCapacity: Int, count: Int) -> DequeBuffer<Element> {
        // First allocation is at least two words
        let realCapacity = max(minimumCapacity,
                               MemoryLayout<Int>.size * 2 / MemoryLayout<Element>.size)
        let managedBuffer = create(minimumCapacity: realCapacity) { _ in
            .init(start: 0, count: count, capacity: realCapacity)
        }
        return unsafeDowncast(managedBuffer, to: DequeBuffer<Element>.self)
    }

    @inlinable
    func erase() {
        withUnsafeMutablePointers { headerPtr, elementsPtr in
            elementsPtr
                .deinitialize(count: headerPtr.pointee.leftSideCount)
            elementsPtr
                .advanced(by: headerPtr.pointee.start)
                .deinitialize(count: headerPtr.pointee.rightSideCount)
            headerPtr.pointee.count = 0
            headerPtr.pointee.start = 0
        }
    }

    @inlinable
    deinit {
        withUnsafeMutablePointers { headerPtr, elementsPtr in
            elementsPtr
                .deinitialize(count: headerPtr.pointee.leftSideCount)
            elementsPtr
                .advanced(by: headerPtr.pointee.start)
                .deinitialize(count: headerPtr.pointee.rightSideCount)
        }
    }

    @inlinable
    func checkSubscriptValid(_ index: Int) {
        precondition(index >= 0 && index < header.count, "Index out of range")
    }

    /// We must ensure that `self` is alive during the call to this method.
    /// We should use `_fixLifetime` after a call to this method.
    @inlinable
    func getElementStorage(_ index: Int) -> UnsafeMutablePointer<Element> {
        withUnsafeMutablePointers { headerPtr, elementsPtr in
            elementsPtr.advanced(by: headerPtr.pointee.position(for: index))
        }
    }

    @inlinable
    func uncheckedSwapAt(_ i: Int, _ j: Int) {
        withUnsafeMutablePointers { headerPtr, elementsPtr in
            let i = headerPtr.pointee.position(for: i)
            let j = headerPtr.pointee.position(for: j)
            let tmp = elementsPtr.advanced(by: i).move()
            elementsPtr
                .advanced(by: i)
                .moveInitialize(from: elementsPtr.advanced(by: j), count: 1)
            elementsPtr
                .advanced(by: j)
                .initialize(to: tmp)
        }
    }

    /// This function assumes that there is enough capacity for adding one more element
    @inlinable
    func uncheckedPrepend(_ newElement: Element) {
        withUnsafeMutablePointers { headerPtr, elementsPtr in
            assert(headerPtr.pointee.capacity > headerPtr.pointee.count)
            if headerPtr.pointee.start > 0 {
                headerPtr.pointee.start &-= 1
            } else {
                headerPtr.pointee.start = headerPtr.pointee.capacity &- 1
            }
            elementsPtr.advanced(by: headerPtr.pointee.start).initialize(to: newElement)
            headerPtr.pointee.count &+= 1
        }
    }

    /// This function assumes that there is enough capacity for adding one more element
    @inlinable
    func uncheckedAppend(_ newElement: Element) {
        withUnsafeMutablePointers { headerPtr, elementsPtr in
            assert(headerPtr.pointee.capacity > headerPtr.pointee.count)
            elementsPtr
                .advanced(by: headerPtr.pointee.position(for: headerPtr.pointee.count))
                .initialize(to: newElement)
            headerPtr.pointee.count &+= 1
        }
    }

    @inlinable
    func uncheckedRemoveFirst() -> Element {
        withUnsafeMutablePointers { headerPtr, elementsPtr in
            assert(headerPtr.pointee.count > 0)
            let removedElement = elementsPtr.advanced(by: header.start).move()
            headerPtr.pointee.count &-= 1
            if headerPtr.pointee.start < headerPtr.pointee.capacity {
                headerPtr.pointee.start &+= 1
            } else {
                headerPtr.pointee.start = 0
            }
            return removedElement
        }
    }

    @inlinable
    func uncheckedRemoveLast() -> Element {
        withUnsafeMutablePointers { headerPtr, elementsPtr in
            assert(headerPtr.pointee.count > 0)
            let indexOfLastElement = headerPtr.pointee.count &- 1
            let removedElement = elementsPtr
                .advanced(by: headerPtr.pointee.position(for: indexOfLastElement)).move()
            headerPtr.pointee.count = indexOfLastElement
            return removedElement
        }
    }

    @inlinable
    func moveInitialize(from other: DequeBuffer) {
        withUnsafeMutablePointers { headerPtr, elementsPtr in
            other.withUnsafeMutablePointers { otherHeaderPtr, otherElementsPtr in
                assert(headerPtr.pointee.start == 0)
                assert(headerPtr.pointee.capacity >= otherHeaderPtr.pointee.count)
                let otherStart = otherHeaderPtr.pointee.start
                let otherLeftSideCount = otherHeaderPtr.pointee.leftSideCount
                let otherRightSideCount = otherHeaderPtr.pointee.rightSideCount
                elementsPtr
                    .moveInitialize(from: otherElementsPtr.advanced(by: otherStart),
                                    count: otherRightSideCount)
                elementsPtr
                    .advanced(by: otherRightSideCount)
                    .moveInitialize(from: otherElementsPtr, count: otherLeftSideCount)
            }
        }
    }

    @inlinable
    func copyInitialize(from other: DequeBuffer) {
        withUnsafeMutablePointers { headerPtr, elementsPtr in
            other.withUnsafeMutablePointers { otherHeaderPtr, otherElementsPtr in
                assert(headerPtr.pointee.start == 0)
                assert(headerPtr.pointee.capacity >= otherHeaderPtr.pointee.count)
                let otherStart = otherHeaderPtr.pointee.start
                let otherLeftSideCount = otherHeaderPtr.pointee.leftSideCount
                let otherRightSideCount = otherHeaderPtr.pointee.rightSideCount
                elementsPtr
                    .initialize(from: otherElementsPtr.advanced(by: otherStart),
                                count: otherRightSideCount)
                elementsPtr
                    .advanced(by: otherRightSideCount)
                    .initialize(from: otherElementsPtr, count: otherLeftSideCount)
            }
        }
    }

    @inlinable
    internal func replaceSubrange<C: Collection>(
      _ subrange: Range<Int>,
      with newCount: Int,
      elementsOf newValues: C
    ) where C.Element == Element {
        withUnsafeMutablePointers { headerPtr, elementsPtr in
            let oldCount = headerPtr.pointee.count
            let eraseCount = subrange.count

            let growth = newCount - eraseCount
            headerPtr.pointee.count = oldCount + growth

            fatalError("unimplemented")
        }
    }
}

extension DequeBuffer: CustomDebugStringConvertible {

    @usableFromInline
    var debugDescription: String {
        var result = """
        DequeBuffer(\
        start: \(header.start), \
        count: \(header.count), \
        capacity: \(header.capacity))[
        """
        withUnsafeMutablePointerToElements { elements -> Void in
            if header.leftSideCount > 0 {
                result += "…"
            }
            var first = true
            for i in 0 ..< header.start {
                if first {
                    first = false
                } else {
                    result += ", "
                }
                if i < header.leftSideCount {
                    debugPrint(elements[i], terminator: "", to: &result)
                } else {
                    print("_", terminator: "", to: &result)
                }
            }
            first = true
            result += "|"
            for i in header.start ..< header.capacity {
                if first {
                    first = false
                } else {
                    result += ", "
                }
                if i - header.start < header.rightSideCount {
                    debugPrint(elements[i], terminator: "", to: &result)
                } else {
                    print("_", terminator: "", to: &result)
                }
            }
            if header.leftSideCount > 0 {
                result += "…"
            }
        }
        result += "]"
        return result
    }
}
