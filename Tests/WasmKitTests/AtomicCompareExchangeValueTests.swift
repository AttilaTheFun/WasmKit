import Testing
import WAT
@testable import WasmKit

@Suite struct AtomicCompareExchangeValueTests {
    @Test(arguments: [EngineConfiguration.ThreadingModel.direct, .token])
    func observedValueAndTruncation(threadingModel: EngineConfiguration.ThreadingModel) throws {
        for (type, width, opcode) in [
            ("i32", 32, "i32.atomic.rmw.cmpxchg"),
            ("i64", 64, "i64.atomic.rmw.cmpxchg"),
            ("i32", 8, "i32.atomic.rmw8.cmpxchg_u"),
            ("i32", 16, "i32.atomic.rmw16.cmpxchg_u"),
            ("i64", 8, "i64.atomic.rmw8.cmpxchg_u"),
            ("i64", 16, "i64.atomic.rmw16.cmpxchg_u"),
            ("i64", 32, "i64.atomic.rmw32.cmpxchg_u"),
        ] {
            let module = try parseWasm(bytes: wat2wasm("""
                (module (memory 1)
                  (func (export "set") (param i64) i32.const 0 local.get 0 i64.store)
                  (func (export "get") (result i64) i32.const 0 i64.load)
                  (func (export "cas") (param \(type) \(type)) (result \(type))
                    i32.const 0 local.get 0 local.get 1 \(opcode)))
                """, features: [.threads]), features: [.threads])
            let instance = try module.instantiate(store: Store(engine: Engine(configuration: .init(threadingModel: threadingModel))))
            let set = try #require(instance.exports[function: "set"])
            let get = try #require(instance.exports[function: "get"])
            let cas = try #require(instance.exports[function: "cas"])
            func value(_ bits: UInt64) -> Value { type == "i64" ? .i64(bits) : .i32(UInt32(truncatingIfNeeded: bits)) }
            let high: UInt64 = width < (type == "i64" ? 64 : 32) ? UInt64(1) << width : 0
            _ = try set([.i64(7)])
            #expect(try cas([value(high | 7), value(high | 11)]) == [value(7)])
            #expect(try get([]) == [.i64(11)])
            #expect(try cas([value(7), value(19)]) == [value(11)])
            #expect(try get([]) == [.i64(11)])
        }
    }
}
