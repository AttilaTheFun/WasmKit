import Testing
import WAT
@_spi(OnlyForCLI) @testable import WasmKit

@Suite struct AtomicRetryTests {
    @Test(arguments: [EngineConfiguration.ThreadingModel.direct, .token])
    func preservesRetryStateAndBothExits(threadingModel: EngineConfiguration.ThreadingModel) throws {
        for metered in [false, true] {
            let module = try parseWasm(bytes: wat2wasm("""
                (module (memory 1)
                  (func (export "set") (param i32 i32) local.get 0 local.get 1 i32.store)
                  (func (export "retry") (param i32 i32 i32) (result i32 i32 i32 i32 i32)
                    (local i32 i32)
                    block $success
                      loop $retry
                        local.get 0 local.get 1 local.get 2 i32.atomic.rmw.cmpxchg
                        local.tee 3 local.get 1 i32.eq br_if $success
                        local.get 3 local.set 1
                        local.get 3 i32.const -512 i32.add local.tee 2
                        i32.const -1 i32.gt_s br_if $retry
                      end
                      i32.const 7 local.set 4
                    end
                    local.get 0 i32.load local.get 1 local.get 2 local.get 3 local.get 4))
                """, features: [.threads]), features: [.threads])
            let config = EngineConfiguration(threadingModel: threadingModel, fuelMetering: metered)
            let store = Store(engine: Engine(configuration: config))
            if metered { store.fuel = Fuel(remaining: 1_000_000) }
            let instance = try module.instantiate(store: store)
            let set = try #require(instance.exports[function: "set"])
            let retry = try #require(instance.exports[function: "retry"])
            for pointer: UInt32 in [0, 65532] {
                for (initial, expected, desired, result): (UInt32, UInt32, UInt32, [UInt32]) in [
                    (1000, 1000, 488, [488, 1000, 488, 1000, 0]),
                    (2000, 1000, 488, [1488, 2000, 1488, 2000, 0]),
                    (100, 1000, 488, [100, 100, 0xfffffe64, 100, 7]),
                    (0xffffffff, 0, 1, [0xffffffff, 0xffffffff, 0xfffffdff, 0xffffffff, 7]),
                    (0x80000100, 0, 1, [0x7fffff00, 0x80000100, 0x7fffff00, 0x80000100, 0]),
                ] {
                    _ = try set([.i32(pointer), .i32(initial)])
                    #expect(try retry([.i32(pointer), .i32(expected), .i32(desired)]) == result.map(Value.i32))
                }
            }
            for pointer: UInt32 in [1, 65533, 65536, .max] {
                #expect(throws: Trap.self) { try retry([.i32(pointer), .i32(0), .i32(1)]) }
            }
            #if Disassembler
            let dumpStore = Store(engine: Engine(configuration: config))
            let dumpInstance = try module.instantiate(store: dumpStore)
            var listing = ""
            try dumpInstance.dumpFunctions(to: &listing, module: module)
            #expect(listing.contains("i32AtomicCmpxchgRetry") == !metered)
            #endif
        }
    }
}
