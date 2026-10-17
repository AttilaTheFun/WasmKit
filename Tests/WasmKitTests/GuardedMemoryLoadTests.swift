import Testing
import WAT
@_spi(Fuzzing) @_spi(OnlyForCLI) @testable import WasmKit

#if os(macOS) || os(iOS) || os(Linux)
private let guardedLoadsSupported = SharedMemoryStorage.isSupported(
    engineConfiguration: Engine(configuration: .init(features: [.threads])).configuration,
    isMemory64: false)

@Suite(.enabled(if: guardedLoadsSupported)) struct GuardedMemoryLoadTests {
    @Test func scalarValuesAndGuardBoundaries() throws {
        let cases: [(String, String, UInt64, Int)] = [
            ("i32.load", "i64.extend_i32_u", 0xffffffff, 4),
            ("i64.load", "", .max, 8),
            ("f32.load", "i32.reinterpret_f32 i64.extend_i32_u", 0xffffffff, 4),
            ("f64.load", "i64.reinterpret_f64", .max, 8),
            ("i32.load8_s", "i64.extend_i32_u", 0xffffffff, 1),
            ("i32.load8_u", "i64.extend_i32_u", 255, 1),
            ("i32.load16_s", "i64.extend_i32_u", 0xffffffff, 2),
            ("i32.load16_u", "i64.extend_i32_u", 65535, 2),
            ("i64.load8_s", "", .max, 1),
            ("i64.load8_u", "", 255, 1),
            ("i64.load16_s", "", .max, 2),
            ("i64.load16_u", "", 65535, 2),
            ("i64.load32_s", "", .max, 4),
            ("i64.load32_u", "", 0xffffffff, 4),
        ]
        for (op, convert, expected, width) in cases {
            let module = try parseWasm(bytes: wat2wasm("""
                (module (memory 1 2 shared)
                  (data (i32.const 0) "\\ff\\ff\\ff\\ff\\ff\\ff\\ff\\ff")
                  (func (export "load") (param i32) (result i64)
                    local.get 0 \(op) \(convert))
                  (func (export "edge") (param i32) (result i64)
                    local.get 0 \(op) offset=\(65536-width) \(convert))
                  (func (export "large") (param i32) (result i64)
                    local.get 0 \(op) offset=4294967295 \(convert))
                  (func (export "grow") (result i32) i32.const 1 memory.grow))
                """, features: [.threads]), features: [.threads])
            let store = Store(engine: Engine(configuration: .init(features: [.threads])))
            let instance = try module.instantiate(store: store)
            let load = try #require(instance.exports[function: "load"])
            let edge = try #require(instance.exports[function: "edge"])
            let large = try #require(instance.exports[function: "large"])
            let grow = try #require(instance.exports[function: "grow"])
            #expect(try load([.i32(0)]) == [.i64(expected)])
            #expect(try edge([.i32(0)]) == [.i64(0)])
            for pointer: UInt32 in [65536, .max] {
                #expect(throws: Trap.self) { try load([.i32(pointer)]) }
                #expect(throws: Trap.self) { try edge([.i32(pointer)]) }
            }
            if width > 1 {
                #expect(throws: Trap.self) { try load([.i32(UInt32(65537-width))]) }
            }
            #expect(throws: Trap.self) { try large([.i32(.max)]) }
            #expect(try grow([]) == [.i32(1)])
            #expect(try load([.i32(65536)]) == [.i64(0)])
            #expect(try load([.i32(0)]) == [.i64(expected)])
            #if Disassembler
            let fresh = try module.instantiate(store: Store(engine: Engine(configuration: .init(features: [.threads]))))
            var listing = ""
            try fresh.dumpFunctions(to: &listing, module: module)
            #expect(listing.contains("Guarded"))
            #endif
        }
    }

    @Test func importedReservationAndZeroPages() throws {
        var config = EngineConfiguration(features: [.threads])
        config.memoryOffsetGuardSize = 0
        let creator = Engine(configuration: config)
        let creatorStore = Store(engine: creator)
        let backing = try SharedMemory(engine: creator, type: MemoryType(min: 0, max: 1, shared: true), resourceLimiter: creatorStore.resourceLimiter)
        #expect(backing.storage.reservationSize >= (1 << 32) + Memory32GuardedLoad.offsetGuardSize)
        let store = Store(engine: Engine(configuration: .init(features: [.threads])))
        let memory = Memory(store: store, sharedMemory: backing)
        let module = try parseWasm(bytes: wat2wasm("""
            (module (import "env" "memory" (memory 0 1 shared))
              (func (export "load") (param i32) (result i64) local.get 0 i64.load offset=65528)
              (func (export "grow") (result i32) i32.const 1 memory.grow))
            """, features: [.threads]), features: [.threads])
        let instance = try module.instantiate(store: store, imports: ["env": ["memory": memory]])
        let load = try #require(instance.exports[function: "load"])
        #expect(throws: Trap.self) { try load([.i32(0)]) }
        #expect(throws: Trap.self) { try load([.i32(.max)]) }
        let grow = try #require(instance.exports[function: "grow"])
        #expect(try grow([]) == [.i32(0)])
        #expect(try load([.i32(0)]) == [.i64(0)])
    }

    @Test func otherMemoriesRemainCheckedAndGuardRestores() throws {
        let module = try parseWasm(bytes: wat2wasm("""
            (module (memory 1 2 shared) (memory 1)
              (func (export "both") (param i32) (result i32)
                i32.const 0 i32.load 1 drop local.get 0 i32.load 0)
              (func (export "other") (param i32) (result i32) local.get 0 i32.load 1))
            """, features: [.threads, .multiMemory]), features: [.threads, .multiMemory])
        let instance = try module.instantiate(store: Store(engine: Engine(configuration: .init(features: [.threads, .multiMemory]))))
        let both = try #require(instance.exports[function: "both"])
        let other = try #require(instance.exports[function: "other"])
        #expect(try both([.i32(0)]) == [.i32(0)])
        #expect(throws: Trap.self) { try other([.i32(65536)]) }
        #expect(throws: Trap.self) { try both([.i32(65536)]) }
        #expect(try both([.i32(0)]) == [.i32(0)])
    }
}
#endif
