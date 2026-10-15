import Testing
import WAT
@testable import WasmKit

@Suite struct Memory32StoreTests {
    @Test(arguments: [EngineConfiguration.ThreadingModel.direct, .token])
    func widthsAndTrapBoundaries(threadingModel: EngineConfiguration.ThreadingModel) throws {
        for shared in [false, true] {
            // Shared memory requires the direct dispatcher's mprotect trap guard.
            if shared && threadingModel == .token { continue }
            for width in [1, 2, 4, 8] {
                let suffix = width == 8 ? "" : "\(width * 8)"
                let loadSuffix = width == 8 ? "" : "\(width * 8)_u"
                let module = try parseWasm(bytes: wat2wasm("""
                    (module (memory 1 2 \(shared ? "shared" : ""))
                      (func (export "write") (param i32 i64) (result i64)
                        local.get 0 local.get 1 i64.store\(suffix)
                        local.get 0 i64.load\(loadSuffix))
                      (func (export "read") (param i32) (result i64)
                        local.get 0 i64.load\(loadSuffix)))
                    """, features: shared ? [.threads] : []), features: shared ? [.threads] : [])
                let store = Store(engine: Engine(configuration: .init(threadingModel: threadingModel)))
                let instance = try module.instantiate(store: store)
                let write = try #require(instance.exports[function: "write"])
                let read = try #require(instance.exports[function: "read"])
                let last = UInt32(65536 - width)
                let mask: UInt64 = width == 8 ? .max : (UInt64(1) << (width * 8)) - 1
                for address: UInt32 in [1, last] {
                    #expect(try write([.i32(address), .i64(.max)]) == [.i64(mask)])
                }
                for address: UInt32 in [last + 1, .max] {
                    #expect(throws: (any Error).self) { try write([.i32(address), .i64(0)]) }
                }
                #expect(try read([.i32(last)]) == [.i64(mask)])
            }
        }
    }
}
