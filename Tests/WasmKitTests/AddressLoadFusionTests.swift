import Testing
import WAT
@_spi(OnlyForCLI) @testable import WasmKit

@Suite struct AddressLoadFusionTests {
    @Test(arguments: [EngineConfiguration.ThreadingModel.direct, .token])
    func wrapsAddressBeforeAddingMemoryOffset(threadingModel: EngineConfiguration.ThreadingModel) throws {
        let module = try parseWasm(bytes: wat2wasm("""
            (module (memory 1)
              (data (i32.const 4) "abcd")
              (func (export "f") (param i32) (result i32 i32) (local i32)
                local.get 0 i32.const 16 i32.add local.tee 1
                i32.load offset=4 local.get 1)
              (func (export "join") (param i32 i32) (result i32)
                block (result i32)
                  local.get 0 local.get 1 br_if 0 drop
                  local.get 0 i32.const 16 i32.add
                end
                i32.load offset=4))
            """))
        let store = Store(engine: Engine(configuration: .init(threadingModel: threadingModel)))
        let instance = try module.instantiate(store: store)
        let f = try #require(instance.exports[function: "f"])
        let join = try #require(instance.exports[function: "join"])
        #expect(try f([.i32(0xfffffff0)]) == [.i32(0x64636261), .i32(0)])
        #expect(try f([.i32(65512)]) == [.i32(0), .i32(65528)])
        #expect(try join([.i32(0), .i32(1)]) == [.i32(0x64636261)])
        #expect(try join([.i32(0xfffffff0), .i32(0)]) == [.i32(0x64636261)])
        for x: UInt32 in [65513, 65516, 0xffffffef] {
            #expect(throws: (any Error).self) { try f([.i32(x)]) }
        }
        #if Disassembler
        let dumpStore = Store(engine: Engine(configuration: .init(threadingModel: threadingModel)))
        let dumpInstance = try module.instantiate(store: dumpStore)
        var listing = ""
        try dumpInstance.dumpFunctions(to: &listing, module: module)
        if threadingModel == .direct { #expect(listing.contains("i32AddImmLoad")) }
        #endif
    }
}

@Suite struct Memory32LoadTests {
    @Test(arguments: [false, true])
    func compactLoadBounds(shared: Bool) throws {
        let module = try parseWasm(bytes: wat2wasm("""
            (module (memory 1 2 \(shared ? "shared" : ""))
              (data (i32.const 65532) "abcd")
              (func (export "load") (param i32) (result i32) local.get 0 i32.load)
              (func (export "offset") (param i32) (result i32) local.get 0 i32.load offset=4294967295))
            """, features: shared ? [.threads] : []), features: shared ? [.threads] : [])
        let store = Store(engine: Engine())
        let instance = try module.instantiate(store: store)
        let load = try #require(instance.exports[function: "load"])
        let offset = try #require(instance.exports[function: "offset"])
        #expect(try load([.i32(65532)]) == [.i32(0x64636261)])
        for x: UInt32 in [65533, 65536, .max] {
            #expect(throws: (any Error).self) { try load([.i32(x)]) }
        }
        for x: UInt32 in [0, 1, .max] {
            #expect(throws: (any Error).self) { try offset([.i32(x)]) }
        }
    }
}

@Suite struct AccumulatorMemory32BoundsTests {
    @Test(arguments: [EngineConfiguration.ThreadingModel.direct, .token])
    func scalarWidthsAndNonWrappingOffsets(threadingModel: EngineConfiguration.ThreadingModel) throws {
        let module = try parseWasm(bytes: wat2wasm("""
            (module (memory 1)
              (data (i32.const 65528) "abcdefgh")
              (func (export "byte") (param i32) (result i32)
                local.get 0 i32.const 0 i32.or i32.load8_u i32.const 1 i32.add)
              (func (export "word") (param i32) (result i64)
                local.get 0 i32.const 0 i32.or i64.load i64.const 1 i64.add)
              (func (export "float") (param i32) (result f64)
                local.get 0 i32.const 0 i32.or f64.load f64.const 0 f64.add)
              (func (export "offset") (param i32) (result i32)
                local.get 0 i32.const 0 i32.or i32.load8_u offset=4294967295)
              (func (export "store-address") (param i32 i64)
                local.get 0 i32.const 0 i32.or local.get 1 i64.store)
              (func (export "store-value") (param i32 i64)
                local.get 0 local.get 1 i64.const 1 i64.add i64.store)
              (func (export "store-offset") (param i32 i64)
                local.get 0 local.get 1 i64.const 1 i64.add i64.store offset=4294967295))
            """))
        let store = Store(engine: Engine(configuration: .init(threadingModel: threadingModel)))
        let instance = try module.instantiate(store: store)
        let byte = try #require(instance.exports[function: "byte"])
        let word = try #require(instance.exports[function: "word"])
        let float = try #require(instance.exports[function: "float"])
        let offset = try #require(instance.exports[function: "offset"])
        #expect(try byte([.i32(65535)]) == [.i32(105)])
        #expect(try word([.i32(65528)]) == [.i64(0x6867666564636262)])
        #expect(try float([.i32(65528)]) == [.f64(0x6867666564636261)])
        for x: UInt32 in [65536, .max] {
            #expect(throws: Trap.self) { try byte([.i32(x)]) }
        }
        for x: UInt32 in [65529, 65536, .max] {
            #expect(throws: Trap.self) { try word([.i32(x)]) }
            #expect(throws: Trap.self) { try float([.i32(x)]) }
        }
        for x: UInt32 in [0, 1, .max] {
            #expect(throws: Trap.self) { try offset([.i32(x)]) }
        }
        for name in ["store-address", "store-value"] {
            let f = try #require(instance.exports[function: name])
            _ = try f([.i32(65528), .i64(123)])
            for x: UInt32 in [65529, 65536, .max] {
                #expect(throws: Trap.self) { try f([.i32(x), .i64(123)]) }
            }
        }
        let storeOffset = try #require(instance.exports[function: "store-offset"])
        for x: UInt32 in [0, 1, .max] {
            #expect(throws: Trap.self) { try storeOffset([.i32(x), .i64(123)]) }
        }
    }
}
