public struct Deque<Element> {

    @usableFromInline
    var _buffer: DequeBuffer<Element>?

    @inlinable
    public init() {
        self.init(buffer: nil)
    }

    @inlinable
    init(buffer: DequeBuffer<Element>?) {
        _buffer = buffer
    }

    @inlinable
    public var capacity: Int { _buffer?.header.capacity ?? 0 }

    @inlinable
    @discardableResult
    func _checkSubscriptValid(_ index: Int) -> DequeBuffer<Element> {
        if let buffer = _buffer {
            buffer.checkSubscriptValid(index)
            return buffer
        } else {
            preconditionFailure("Index out of range")
        }
    }

    @inlinable
    mutating func _makeUniqueAndReserveCapacityIfNotUnique() {
      if _slowPath(!isKnownUniquelyReferenced(&_buffer)) {
        _createNewBuffer(bufferIsUnique: false,
                         minimumCapacity: count + 1,
                         growForAppend: true)
      }
    }

    @inlinable
    mutating func _makeUnique() {
        if _slowPath(!isKnownUniquelyReferenced(&_buffer)) {
            _createNewBuffer(bufferIsUnique: false,
                             minimumCapacity: count,
                             growForAppend: false)
        }
    }

    @inlinable
    mutating func _reserveCapacityAssumingUniqueBuffer(oldCount: Int) {
        if _slowPath(oldCount + 1 > _buffer.unsafelyUnwrapped.header.capacity) {
            _createNewBuffer(bufferIsUnique: true,
                             minimumCapacity: oldCount + 1,
                             growForAppend: true)
        }
    }

    @inlinable
    internal func _growDequeCapacity(_ capacity: Int) -> Int { capacity * 2 }

    @inlinable
    internal func _growDequeCapacity(oldCapacity: Int,
                                     minimumCapacity: Int,
                                     growForAppend: Bool) -> Int {
      if growForAppend {
        if oldCapacity < minimumCapacity {
          // When appending to a deque, grow exponentially.
          return Swift.max(minimumCapacity, _growDequeCapacity(oldCapacity))
        }
        return oldCapacity
      }
      // If not for append, just use the specified capacity, ignoring oldCapacity.
      // This means that we "shrink" the buffer in case minimumCapacity is less
      // than oldCapacity.
      return minimumCapacity
    }

    /// Creates a new buffer, replacing the current buffer.
    ///
    /// If `bufferIsUnique` is true, the buffer is assumed to be uniquely
    /// referenced by this deque and the elements are moved - instead of copied -
    /// to the new buffer.
    /// The `minimumCapacity` is the lower bound for the new capacity.
    /// If `growForAppend` is true, the new capacity is calculated using
    /// `_growDequeCapacity(_:)`.
    @inlinable
    mutating func _createNewBuffer(bufferIsUnique: Bool,
                                   minimumCapacity: Int,
                                   growForAppend: Bool) {
        let newCapacity = _growDequeCapacity(oldCapacity: capacity,
                                             minimumCapacity: minimumCapacity,
                                             growForAppend: growForAppend)
        let count = self.count
        assert(newCapacity >= count)
        let newBuffer = DequeBuffer<Element>.create(minimumCapacity: newCapacity,
                                                    count: count)

        if bufferIsUnique {
            assert(isKnownUniquelyReferenced(&_buffer))
            // As an optimization, if the original buffer is unique, we can just move
            // the elements instead of copying.
            newBuffer.moveInitialize(from: _buffer.unsafelyUnwrapped)
        } else if let oldBuffer = _buffer {
            newBuffer.copyInitialize(from: oldBuffer)
        }
        _buffer = newBuffer
    }

    /// Reserves enough space to store `minimumCapacity` elements.
    /// If a new buffer needs to be allocated and `growForAppend` is true,
    /// the new capacity is calculated using `_growArrayCapacity`.
    @inlinable
    mutating func _reserveCapacityImpl(minimumCapacity: Int, growForAppend: Bool) {
        let isUnique = isKnownUniquelyReferenced(&_buffer)
        if _slowPath(!isUnique || capacity < minimumCapacity) {
            _createNewBuffer(bufferIsUnique: isUnique,
                             minimumCapacity: Swift.max(minimumCapacity, count),
                             growForAppend: growForAppend)
        }
        assert(capacity >= minimumCapacity)
        assert(capacity == 0 || isKnownUniquelyReferenced(&_buffer))
    }

    @inlinable
    mutating func reserveCapacityForAppend(newElementsCount: Int) {
      // Ensure uniqueness, mutability, and sufficient storage. Note that
      // for consistency, we need unique self even if newElements is empty.
      _reserveCapacityImpl(minimumCapacity: count + newElementsCount,
                           growForAppend: true)
    }
}

extension Deque: Collection {

    @inlinable
    public var startIndex: Int { 0 }

    @inlinable
    public var endIndex: Int { count }

    @inlinable
    public subscript(position: Int) -> Element {
        get {
            defer { _fixLifetime(_buffer) }
            return _checkSubscriptValid(position).getElementStorage(position).pointee
        }
        _modify {
            defer { _fixLifetime(_buffer) }
            _makeUnique()
            yield &_checkSubscriptValid(position).getElementStorage(position).pointee
        }
    }

    @inlinable
    public subscript(bounds: Range<Int>) -> Slice<Self> {
        get {
            fatalError("unimplemented")
        }
        set {
            fatalError("unimplemented")
        }
    }

    @inlinable
    public func index(after i: Int) -> Int { i + 1 }

    @inlinable
    public func formIndex(after i: inout Int) {
        i += 1
    }

    @inlinable
    public var indices: Range<Int> { startIndex ..< endIndex }

    @inlinable
    public var isEmpty: Bool { count == 0 }

    @inlinable
    public var count: Int { _buffer?.header.count ?? 0 }

    @inlinable
    public func index(_ i: Int, offsetBy distance: Int) -> Int { i + distance }

    @inlinable
    public func index(_ i: Int, offsetBy distance: Int, limitedBy limit: Int) -> Int? {
        let l = limit - i
        if distance > 0 ? (l >= 0 && l < distance) : (l <= 0 && distance < l) {
          return nil
        }
        return i + distance
    }

    @inlinable
    public func distance(from start: Int, to end: Int) -> Int { end - start }
}

extension Deque: BidirectionalCollection {

    @inlinable
    public func index(before i: Int) -> Int {
        i - 1
    }

    @inlinable
    public func formIndex(before i: inout Int) {
        i -= 1
    }
}

extension Deque: RandomAccessCollection {}

extension Deque: MutableCollection {

    @inlinable
    public mutating func partition(
        by belongsInSecondPartition: (Element) throws -> Bool
    ) rethrows -> Int {
        // TODO: Do we need to provide custom implementation at all?
        fatalError("unimplemented")
    }

    @inlinable
    public mutating func swapAt(_ i: Int, _ j: Int) {
        _checkSubscriptValid(i)
        _checkSubscriptValid(j).uncheckedSwapAt(i, j)
    }
}

extension Deque: RangeReplaceableCollection {

    @inlinable
    public mutating func replaceSubrange<C: Collection>(
        _ subrange: Range<Int>,
        with newElements: C
    ) where C.Element == Element {
        precondition(subrange.lowerBound >= startIndex,
                     "ContiguousArray replace: subrange start is negative")
        precondition(subrange.upperBound <= endIndex,
                     "ContiguousArray replace: subrange extends past the end")

        let eraseCount = subrange.count
        let insertCount = newElements.count
        let growth = insertCount - eraseCount

        reserveCapacityForAppend(newElementsCount: growth)
        _buffer?.replaceSubrange(subrange, with: insertCount, elementsOf: newElements)
    }

    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        _reserveCapacityImpl(minimumCapacity: minimumCapacity,
                             growForAppend: false)
    }

    @inlinable
    public init(repeating repeatedValue: Element, count: Int) {
        precondition(count >= 0, "count must not be negative")
        if count == 0 {
            self.init(buffer: nil)
        } else {
            let buffer = DequeBuffer<Element>.create(minimumCapacity: count, count: count)
            buffer.withUnsafeMutablePointerToElements {
                $0.initialize(repeating: repeatedValue, count: count)
            }
            self.init(buffer: buffer)
        }
    }

    @inlinable
    public init<S: Sequence>(_ elements: S) where S.Element == Element {
        if let otherDeque = elements as? Deque<Element> {
            self.init(buffer: otherDeque._buffer)
            return
        }
        self.init()
        append(contentsOf: elements)
    }

    @inlinable
    public mutating func append(_ newElement: Element) {
        // Separating uniqueness check and capacity check allows hoisting the
        // uniqueness check out of a loop.
        _makeUniqueAndReserveCapacityIfNotUnique()
        _reserveCapacityAssumingUniqueBuffer(oldCount: count)
        _buffer!.uncheckedAppend(newElement)
    }

    @inlinable
    public mutating func append<S: Sequence>(contentsOf newElements: S)
        where Element == S.Element
    {
        let newElementsCount = newElements.underestimatedCount
        reserveCapacityForAppend(newElementsCount: newElementsCount)
        let oldCount = count

        var remainder: S.Iterator? = _buffer?
            .withUnsafeMutablePointers { headerPtr, elementsPtr in
                let buf = UnsafeMutableBufferPointer(
                    start: elementsPtr + oldCount,
                    count: headerPtr.pointee.capacity - oldCount
                )
                let (remainder, writtenUpTo) = buf.initialize(from: newElements)

                // trap on underflow from the sequence's underestimate:
                let writtenCount = buf.distance(from: buf.startIndex, to: writtenUpTo)
                precondition(newElementsCount <= writtenCount,
                             "newElements.underestimatedCount was an overestimate")
                // can't check for overflow as sequences can underestimate

                if writtenCount > 0 {
                    headerPtr.pointee.count += writtenCount
                }

                return remainder
            }

        while let nextItem = remainder?.next() {
            _reserveCapacityAssumingUniqueBuffer(oldCount: count)
            _buffer!.uncheckedAppend(nextItem)
        }
    }

    @inlinable
    public mutating func prepend(_ newElement: Element) {
        // Separating uniqueness check and capacity check allows hoisting the
        // uniqueness check out of a loop.
        _makeUniqueAndReserveCapacityIfNotUnique()
        _reserveCapacityAssumingUniqueBuffer(oldCount: count)
        _buffer!.uncheckedPrepend(newElement)
    }

    @inlinable
    public mutating func insert(_ newElement: Element, at i: Int) {
        fatalError("unimplemented")
    }

    @inlinable
    public mutating func insert<C: Collection>(contentsOf newElements: C, at i: Int)
        where Element == C.Element
    {
        fatalError("unimplemented")
    }

    @inlinable
    public mutating func remove(at position: Int) -> Element {
        precondition(!isEmpty, "Can't remove from an empty collection")
        fatalError("unimplemented")
    }

    @inlinable
    public mutating func removeSubrange(_ bounds: Range<Int>) {
        fatalError("unimplemented")
    }

    @inlinable
    public mutating func _customRemoveLast() -> Element? {
        return removeLast()
    }

    @inlinable
    @discardableResult
    public mutating func _customRemoveLast(_ n: Int) -> Bool {
        removeLast(n)
        return true
    }

    @inlinable
    public mutating func removeFirst() -> Element {
        fatalError("unimplemented")
    }

    @inlinable
    public mutating func removeFirst(_ k: Int) {
        fatalError("unimplemented")
    }

    @inlinable
    public mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
        if keepCapacity && _buffer != nil {
            _makeUnique()
            _buffer!.erase()
        } else {
            _buffer = nil
        }
    }
}

extension Deque {

    @inlinable
    public mutating func removeLast() -> Element {
        precondition(!isEmpty, "Can't remove last element from an empty collection")
        fatalError("unimplemented")
    }

    @inlinable
    public mutating func removeLast(_ k: Int) {
        if k == 0 { return }
        precondition(k >= 0,
                     "Number of elements to remove should be non-negative")
        precondition(count >= k,
                     "Can't remove more items from a collection than it contains")
        fatalError("unimplemented")
    }
}

extension Deque: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = Element

    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension Deque: Equatable where Element: Equatable {

    @inlinable
    public static func == (lhs: Deque<Element>, rhs: Deque<Element>) -> Bool {
        let lhsCount = lhs.count
        guard lhsCount == rhs.count else {
            return false
        }

        // Test referential equality.
        if lhsCount == 0 || lhs._buffer === rhs._buffer {
          return true
        }

        // We know that lhs.count == rhs.count, compare element wise.
        for i in 0 ..< lhsCount where lhs[i] != rhs[i] {
            return false
        }
        return true
    }
}

extension Deque: Hashable where Element: Hashable {

    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for element in self {
            hasher.combine(element)
        }
    }
}

extension Deque {

    /// This function is taken from the Swift Standard Library
    private func _makeDescription(
        withTypeName: Bool
    ) -> String {
        var result = withTypeName ? "Deque([" : "["
        var first = true
        for item in self {
            if first {
                first = false
            } else {
                result += ", "
            }
            debugPrint(item, terminator: "", to: &result)
        }
        result += withTypeName ? "])" : "]"
        return result
    }
}

extension Deque: CustomStringConvertible {
    public var description: String {
        _makeDescription(withTypeName: false)
    }
}

extension Deque: CustomDebugStringConvertible {
    public var debugDescription: String {
        _makeDescription(withTypeName: true)
    }
}
