import Testing
import WAT
@_spi(OnlyForCLI) @testable import WasmKit

@Suite struct AtomicUpdateTests {
    @Test(arguments: [EngineConfiguration.ThreadingModel.direct, .token])
    func preservesInitialLoadAndBothExits(threadingModel: EngineConfiguration.ThreadingModel) throws {
        for metered in [false, true] {
            let module = try parseWasm(bytes: wat2wasm("""
                (module (memory 1)
                  (func (export "set") (param i32 i32) local.get 0 local.get 1 i32.store)
                  (func (export "update") (param i32 i32) (result i32 i32 i32 i32)
                    (local i32 i32 i32)
                    block $success
                      block $failed
                        block $initial
                          local.get 0 i32.atomic.load offset=4 local.tee 0
                          i32.const -512 i32.add local.tee 2
                          i32.const 0 i32.ge_s br_if $initial
                          local.get 0 local.set 3
                          br $failed
                        end
                        loop $retry
                          local.get 1 local.get 0 local.get 2 i32.atomic.rmw.cmpxchg
                          local.tee 3 local.get 0 i32.eq br_if $success
                          local.get 3 local.set 0
                          local.get 3 i32.const -512 i32.add local.tee 2
                          i32.const -1 i32.gt_s br_if $retry
                        end
                      end
                      i32.const 7 local.set 4
                    end
                    local.get 0 local.get 2 local.get 3 local.get 4))
                """, features: [.threads]), features: [.threads])
            let config = EngineConfiguration(threadingModel: threadingModel, fuelMetering: metered)
            let store = Store(engine: Engine(configuration: config))
            if metered { store.fuel = Fuel(remaining: 1_000_000) }
            let instance = try module.instantiate(store: store)
            let set = try #require(instance.exports[function: "set"])
            let update = try #require(instance.exports[function: "update"])
            for (initial, other, result): (UInt32, UInt32, [UInt32]) in [
                (1000, 1000, [1000, 488, 1000, 0]),
                (1000, 2000, [2000, 1488, 2000, 0]),
                (1000, 100, [100, 0xfffffe64, 100, 7]),
                (100, 1000, [100, 0xfffffe64, 100, 7]),
                (0x80000100, 0x80000100, [0x80000100, 0x7fffff00, 0x80000100, 0]),
                (0xffffffff, 1000, [0xffffffff, 0xfffffdff, 0xffffffff, 7]),
            ] {
                _ = try set([.i32(4), .i32(initial)])
                _ = try set([.i32(8), .i32(other)])
                #expect(try update([.i32(0), .i32(8)]) == result.map(Value.i32))
            }
            // The initial load uses a non-wrapping effective address. An early
            // negative exit must not access the independent CAS pointer.
            _ = try set([.i32(4), .i32(100)])
            #expect(try update([.i32(0), .i32(.max)]) == [100, 0xfffffe64, 100, 7].map(Value.i32))
            for pointer: UInt32 in [1, 65532, 0xfffffffc, .max] {
                #expect(throws: Trap.self) { try update([.i32(pointer), .i32(8)]) }
            }
            _ = try set([.i32(4), .i32(1000)])
            for pointer: UInt32 in [1, 65536, .max] {
                #expect(throws: Trap.self) { try update([.i32(0), .i32(pointer)]) }
            }
            #if Disassembler
            let dumpStore = Store(engine: Engine(configuration: config))
            let dumpInstance = try module.instantiate(store: dumpStore)
            var listing = ""
            try dumpInstance.dumpFunctions(to: &listing, module: module)
            #expect(listing.contains("i32AtomicCmpxchgUpdate") == !metered)
            #endif
        }
    }
}
