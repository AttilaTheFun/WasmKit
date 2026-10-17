import Testing
import WAT
@_spi(OnlyForCLI) @testable import WasmKit

@Suite struct VariableAddressLoadTests {
    @Test(arguments: [EngineConfiguration.ThreadingModel.direct, .token])
    func wrappingAliasingAndControlFlow(threadingModel: EngineConfiguration.ThreadingModel) throws {
        let module = try parseWasm(bytes: wat2wasm("""
            (module (memory 1)
              (data (i32.const 4) "abcd")
              (func (export "f") (param i32 i32) (result i32 i32) (local i32)
                local.get 0 local.get 1 i32.add local.tee 2
                i32.load offset=4 local.get 2)
              (func (export "alias") (param i32 i32) (result i32 i32)
                local.get 0 local.get 1 i32.add local.tee 0
                i32.load offset=4 local.get 0)
              (func (export "resultAlias") (param i32 i32) (result i32)
                local.get 0 local.get 1 i32.add i32.load offset=4 local.set 0 local.get 0)
              (func (export "acc") (param i32 i32) (result i32 i32) (local i32)
                local.get 0 i32.const 1 i32.shl local.get 1 i32.add local.tee 2
                i32.load offset=4 local.get 2)
              (func (export "accLoad") (param i32 i32) (result i32)
                local.get 0 i32.load local.get 1 i32.add i32.load offset=4)
              (func (export "join") (param i32 i32 i32) (result i32)
                block (result i32)
                  local.get 0 local.get 2 br_if 0 drop
                  local.get 0 local.get 1 i32.add
                end
                i32.load offset=4))
            """))
        for metered in [false, true] {
            let config = EngineConfiguration(threadingModel: threadingModel, fuelMetering: metered)
            let store = Store(engine: Engine(configuration: config))
            if metered { store.fuel = Fuel(remaining: 1_000_000) }
            let instance = try module.instantiate(store: store)
            for name in ["f", "alias"] {
                let f = try #require(instance.exports[function: name])
                #expect(try f([.i32(0xfffffff0), .i32(16)]) == [.i32(0x64636261), .i32(0)])
                #expect(try f([.i32(65520), .i32(8)]) == [.i32(0), .i32(65528)])
                for x: UInt32 in [65529, 65532, 0xfffffffc] {
                    #expect(throws: Trap.self) { try f([.i32(x), .i32(0)]) }
                }
            }
            let resultAlias = try #require(instance.exports[function: "resultAlias"])
            #expect(try resultAlias([.i32(0xfffffff0), .i32(16)]) == [.i32(0x64636261)])
            let acc = try #require(instance.exports[function: "acc"])
            #expect(try acc([.i32(0xfffffff8), .i32(16)]) == [.i32(0x64636261), .i32(0)])
            #expect(throws: Trap.self) { try acc([.i32(32768), .i32(0)]) }
            let accLoad = try #require(instance.exports[function: "accLoad"])
            #expect(try accLoad([.i32(0), .i32(0)]) == [.i32(0x64636261)])
            #expect(throws: Trap.self) { try accLoad([.i32(65536), .i32(0)]) }
            #expect(throws: Trap.self) { try accLoad([.i32(0), .i32(65536)]) }
            let join = try #require(instance.exports[function: "join"])
            #expect(try join([.i32(0), .i32(16), .i32(1)]) == [.i32(0x64636261)])
            #expect(try join([.i32(0xfffffff0), .i32(16), .i32(0)]) == [.i32(0x64636261)])
            #if Disassembler
            let dumpInstance = try module.instantiate(store: Store(engine: Engine(configuration: config)))
            var listing = ""
            try dumpInstance.dumpFunctions(to: &listing, module: module)
            if threadingModel == .direct {
                #expect(listing.contains("i32AddLoad"))
                #expect(listing.contains("i32AddAccLoad"))
            }
            #endif
        }
    }
}
