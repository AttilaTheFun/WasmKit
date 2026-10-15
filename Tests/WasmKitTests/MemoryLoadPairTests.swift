import Testing
import WAT
@_spi(OnlyForCLI) @testable import WasmKit

@Suite struct MemoryLoadPairTests {
    @Test(arguments: [EngineConfiguration.ThreadingModel.direct, .token], [EngineConfiguration.MemoryBoundsChecking.software, .mprotect])
    func preservesResultsAndBounds(threadingModel: EngineConfiguration.ThreadingModel, bounds: EngineConfiguration.MemoryBoundsChecking) throws {
        let module = try parseWasm(bytes: wat2wasm("""
            (module (memory 1)
              (data (i32.const 0) "abcdefgh")
              (data (i32.const 65532) "wxyz")
              (func (export "pair") (param i32 i32) (result i32 i32) (local i32 i32)
                local.get 0 i32.load local.set 2
                local.get 1 i32.load local.set 3
                local.get 2 local.get 3)
              (func (export "offset") (param i32 i32) (result i32 i32) (local i32 i32)
                local.get 0 i32.load offset=1 local.set 2
                local.get 1 i32.load offset=4294967295 local.set 3
                local.get 2 local.get 3)
              (func (export "join") (param i32 i32 i32) (result i32 i32) (local i32 i32)
                block
                  local.get 2 br_if 0
                  local.get 0 i32.load local.set 3
                end
                local.get 1 i32.load local.set 4
                local.get 3 local.get 4))
            """))
        let store = Store(engine: Engine(configuration: .init(threadingModel: threadingModel, memoryBoundsChecking: bounds)))
        let instance = try module.instantiate(store: store)
        let pair = try #require(instance.exports[function: "pair"])
        #expect(try pair([.i32(0), .i32(4)]) == [.i32(0x64636261), .i32(0x68676665)])
        #expect(try pair([.i32(1), .i32(65532)]) == [.i32(0x65646362), .i32(0x7a797877)])
        #expect(try pair([.i32(65532), .i32(0)]) == [.i32(0x7a797877), .i32(0x64636261)])
        for bad: UInt32 in [65533, 65536, .max] {
            #expect(throws: (any Error).self) { try pair([.i32(bad), .i32(0)]) }
            #expect(throws: (any Error).self) { try pair([.i32(0), .i32(bad)]) }
        }
        let offset = try #require(instance.exports[function: "offset"])
        for p: UInt32 in [0, 1, .max] {
            #expect(throws: (any Error).self) { try offset([.i32(0), .i32(p)]) }
        }
        let join = try #require(instance.exports[function: "join"])
        #expect(try join([.i32(0), .i32(4), .i32(0)]) == [.i32(0x64636261), .i32(0x68676665)])
        #expect(try join([.i32(.max), .i32(4), .i32(1)]) == [.i32(0), .i32(0x68676665)])
        #if Disassembler
        if threadingModel == .direct {
            let dumpStore = Store(engine: Engine(configuration: .init(threadingModel: threadingModel, memoryBoundsChecking: bounds)))
            let dumpInstance = try module.instantiate(store: dumpStore)
            var listing = ""
            try dumpInstance.dumpFunctions(to: &listing, module: module)
            #expect(listing.contains("i32LoadMemory32Pair"))
        }
        #endif
    }
}
