import Testing
import WAT
@_spi(OnlyForCLI) @testable import WasmKit

@Suite struct GlobalReturnFusionTests {
    @Test(arguments: [EngineConfiguration.ThreadingModel.direct, .token])
    func updateBeforeReturn(threadingModel: EngineConfiguration.ThreadingModel) throws {
        let module = try parseWasm(bytes: wat2wasm("""
            (module
              (global $g (mut i32) (i32.const 0))
              (func $update (param i32)
                local.get 0 i32.const 16 i32.add global.set $g)
              (func (export "call") (param i32) (result i32)
                local.get 0 call $update global.get $g)
              (func (export "explicit") (param i32)
                local.get 0 i32.const 16 i32.add global.set $g return)
              (func (export "join") (param i32 i32)
                block
                  local.get 1 br_if 0
                  local.get 0 i32.const 16 i32.add global.set $g
                end)
              (func (export "updateThenCall") (param i32)
                local.get 0 i32.const 16 i32.add global.set $g
                i32.const 99 call $update)
              (func (export "read") (result i32) global.get $g))
            """))
        for mode: EngineConfiguration.CompilationMode in [.lazy, .eager] {
            let store = Store(engine: Engine(configuration: .init(threadingModel: threadingModel, compilationMode: mode)))
            let instance = try module.instantiate(store: store)
            let call = try #require(instance.exports[function: "call"])
            let explicit = try #require(instance.exports[function: "explicit"])
            let join = try #require(instance.exports[function: "join"])
            let updateThenCall = try #require(instance.exports[function: "updateThenCall"])
            let read = try #require(instance.exports[function: "read"])
            for x: UInt32 in [0, 1, .max, 0xfffffff0, 0x80000000] {
                #expect(try updateThenCall([.i32(x)]) == [])
                #expect(try read([]) == [.i32(115)])
                #expect(try call([.i32(x)]) == [.i32(x &+ 16)])
                #expect(try explicit([.i32(x)]) == [])
                #expect(try read([]) == [.i32(x &+ 16)])
                #expect(try join([.i32(99), .i32(1)]) == [])
                #expect(try read([]) == [.i32(x &+ 16)])
                #expect(try join([.i32(x), .i32(0)]) == [])
                #expect(try read([]) == [.i32(x &+ 16)])
            }
        }
        #if Disassembler
        let store = Store(engine: Engine(configuration: .init(threadingModel: threadingModel)))
        let instance = try module.instantiate(store: store)
        var listing = ""
        try instance.dumpFunctions(to: &listing, module: module)
        if threadingModel == .direct {
            #expect(listing.contains("i32AddImmGlobalSetReturn"))
        }
        #endif
    }
}
