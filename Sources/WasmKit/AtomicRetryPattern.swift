/// A canonical compare-exchange retry loop with a signed-positive retry guard.
/// Matching bytes is only a selection hint: the normal translator still validates
/// every instruction, and emits the original loop for instruction mapping.
struct AtomicRetryPattern {
    let pointer: UInt32
    let expected: UInt32
    let replacement: UInt32
    let observed: UInt32
    let successDepth: UInt32
    let delta: Int32
    let end: Int

    static func match(_ bytes: ArraySlice<UInt8>, at start: Int) -> Self? {
        var cursor = start
        func take(_ byte: UInt8) -> Bool {
            guard cursor < bytes.endIndex, bytes[cursor] == byte else { return false }
            cursor += 1
            return true
        }
        // Canonical one-byte local/depth indices keep this matcher deliberately
        // narrow. Other encodings and loop shapes use normal interpretation.
        func index() -> UInt32? {
            guard cursor < bytes.endIndex, bytes[cursor] < 128 else { return nil }
            defer { cursor += 1 }
            return UInt32(bytes[cursor])
        }
        guard take(0x03), take(0x40), take(0x20), let pointer = index(),
            take(0x20), let expected = index(), take(0x20), let replacement = index(),
            take(0xfe), take(0x48), take(0x02), take(0x00),
            take(0x22), let observed = index(), take(0x20), index() == expected,
            take(0x46), take(0x0d), let depth = index(), depth > 0,
            take(0x20), index() == observed, take(0x21), index() == expected,
            take(0x20), index() == observed, take(0x41) else { return nil }
        var value: Int64 = 0
        var shift = 0
        var byte: UInt8 = 0
        repeat {
            guard cursor < bytes.endIndex, shift < 35 else { return nil }
            byte = bytes[cursor]; cursor += 1
            value |= Int64(byte & 0x7f) << shift
            shift += 7
        } while byte & 0x80 != 0
        if byte & 0x40 != 0 { value |= (-1 as Int64) << shift }
        guard let delta = Int32(exactly: value),
            take(0x6a), take(0x22), index() == replacement,
            take(0x41), take(0x7f), take(0x4a), take(0x0d), take(0x00), take(0x0b),
            Set([pointer, expected, replacement, observed]).count == 4 else { return nil }
        return Self(pointer: pointer, expected: expected, replacement: replacement,
            observed: observed, successDepth: depth, delta: delta, end: cursor - 1)
    }
}

/// The initial load/check followed by the canonical retry loop. The load's
/// effective address is independent of the pointer used by compare-exchange.
struct AtomicUpdatePattern {
    let retry: AtomicRetryPattern
    let offset: UInt32
    let end: Int

    static func match(_ bytes: ArraySlice<UInt8>, at start: Int) -> Self? {
        var cursor = start
        func take(_ byte: UInt8) -> Bool {
            guard cursor < bytes.endIndex, bytes[cursor] == byte else { return false }
            cursor += 1
            return true
        }
        func index() -> UInt32? {
            guard cursor < bytes.endIndex, bytes[cursor] < 128 else { return nil }
            defer { cursor += 1 }
            return UInt32(bytes[cursor])
        }
        guard take(0x02), take(0x40), take(0x02), take(0x40),
            take(0x20), let expected = index(),
            take(0xfe), take(0x10), take(0x02), let offset = index(),
            take(0x22), index() == expected, take(0x41) else { return nil }
        let deltaStart = cursor
        var count = 0
        while cursor < bytes.endIndex {
            let byte = bytes[cursor]; cursor += 1; count += 1
            if byte & 0x80 == 0 { break }
            if count == 5 { return nil }
        }
        let deltaBytes = bytes[deltaStart..<cursor]
        guard take(0x6a), take(0x22), let replacement = index(),
            take(0x41), take(0x00), take(0x4e), take(0x0d), take(0x00),
            take(0x20), index() == expected, take(0x21), let observed = index(),
            take(0x0c), take(0x01), take(0x0b),
            let retry = AtomicRetryPattern.match(bytes, at: cursor),
            retry.expected == expected, retry.replacement == replacement,
            retry.observed == observed, retry.successDepth > 1 else { return nil }
        // Require identical signed-LEB encoding for the two additions, rather
        // than accepting a second, independently implemented integer decoder.
        let retryDeltaStart = retry.end - 8 - deltaBytes.count
        guard retryDeltaStart >= cursor,
            bytes[retryDeltaStart..<(retryDeltaStart + deltaBytes.count)].elementsEqual(deltaBytes)
        else { return nil }
        cursor = retry.end + 1
        guard take(0x0b) else { return nil }
        return Self(retry: retry, offset: offset, end: cursor - 1)
    }
}
