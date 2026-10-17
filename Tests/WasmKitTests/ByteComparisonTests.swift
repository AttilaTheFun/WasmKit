import Testing
import WAT
@testable import WasmKit

@Suite struct ByteComparisonTests {
    static let function = """
     (func $compare (param $0 i32) (param $1 i32) (param $2 i32) (result i32)
      (local $3 i32)
      (local $4 i32)
      (local $5 i32)
      (local.set $3
       (i32.const 0)
      )
      (block $block
       (br_if $block
        (i32.eqz
         (local.get $2)
        )
       )
       (block $block1
        (loop $label
         (br_if $block1
          (i32.ne
           (local.tee $4
            (i32.load8_u
             (local.get $0)
            )
           )
           (local.tee $5
            (i32.load8_u
             (local.get $1)
            )
           )
          )
         )
         (local.set $1
          (i32.add
           (local.get $1)
           (i32.const 1)
          )
         )
         (local.set $0
          (i32.add
           (local.get $0)
           (i32.const 1)
          )
         )
         (br_if $label
          (local.tee $2
           (i32.add
            (local.get $2)
            (i32.const -1)
           )
          )
         )
         (br $block)
        )
       )
       (local.set $3
        (i32.sub
         (local.get $4)
         (local.get $5)
        )
       )
      )
      (local.get $3)
     )
    """

    @Test(arguments: [EngineConfiguration.ThreadingModel.direct, .token])
    func exactResultsAndBoundaryFallback(threadingModel: EngineConfiguration.ThreadingModel) throws {
        for metered in [false, true] {
            let module = try parseWasm(bytes: wat2wasm("""
                (module (type $0 (func (param i32 i32 i32) (result i32)))
                  (memory 1)
                  \(Self.function)
                  (export "compare" (func $compare))
                  (func (export "set") (param i32 i32)
                    local.get 0 local.get 1 i32.store8))
                """))
            let store = Store(engine: Engine(configuration: .init(threadingModel: threadingModel, fuelMetering: metered)))
            if metered { store.fuel = Fuel(remaining: 1_000_000) }
            let instance = try module.instantiate(store: store)
            let compare = try #require(instance.exports[function: "compare"])
            let set = try #require(instance.exports[function: "set"])
            for i in 0..<64 {
                _ = try set([.i32(UInt32(i)), .i32(UInt32(i * 3))])
                _ = try set([.i32(UInt32(128+i)), .i32(UInt32(i * 3))])
            }
            for count: UInt32 in [0, 1, 7, 8, 9, 15, 16, 17, 64] {
                #expect(try compare([.i32(0), .i32(128), .i32(count)]) == [.i32(0)])
                if count > 0 {
                    _ = try set([.i32(128+count-1), .i32(255)])
                    let difference = Int32((count-1)*3) - 255
                    #expect(try compare([.i32(0), .i32(128), .i32(count)]) == [.i32(UInt32(bitPattern: difference))])
                    #expect(try compare([.i32(128), .i32(0), .i32(count)]) == [.i32(UInt32(bitPattern: -difference))])
                    _ = try set([.i32(128+count-1), .i32((count-1)*3)])
                }
            }
            #expect(try compare([.i32(.max), .i32(.max), .i32(0)]) == [.i32(0)])
            _ = try set([.i32(65535), .i32(255)])
            // The requested ranges exceed memory, but an early mismatch returns
            // before the original loop touches an out-of-bounds byte.
            #expect(try compare([.i32(65535), .i32(0), .i32(2)]) == [.i32(255)])
            #expect(throws: Trap.self) { try compare([.i32(65535), .i32(65535), .i32(2)]) }
            #expect(throws: Trap.self) { try compare([.i32(.max), .i32(0), .i32(1)]) }
            let (code, _) = instance.handle.functions[0].assumeCompiled()
            let zero = VReg(slotIndex: 0)
            let expected = Instruction.byteCompareReturn(.init(lhs: zero, rhs: zero, count: zero, result: LVReg(zero)))
            #expect((code.instructions[0] == expected.headSlotInline(threadingModel: threadingModel)) == !metered)
        }
    }
    @Test(.enabled(if: Engine().configuration.memoryBoundsChecking == .mprotect))
    func sharedMemoryUsesCommittedBound() throws {
        let module = try parseWasm(bytes: wat2wasm("""
            (module (type $0 (func (param i32 i32 i32) (result i32)))
              (memory 1 2 shared)
              \(Self.function)
              (export "compare" (func $compare))
              (func (export "set") (param i32 i32)
                local.get 0 local.get 1 i32.store8))
            """, features: [.threads]), features: [.threads])
        let store = Store(engine: Engine(configuration: .init(features: [.threads])))
        let instance = try module.instantiate(store: store)
        let compare = try #require(instance.exports[function: "compare"])
        _ = try instance.exports[function: "set"]!([.i32(65535), .i32(255)])
        #expect(try compare([.i32(65535), .i32(0), .i32(2)]) == [.i32(255)])
        #expect(try compare([.i32(.max), .i32(.max), .i32(0)]) == [.i32(0)])
        #expect(throws: Trap.self) { try compare([.i32(65535), .i32(65535), .i32(2)]) }
    }

}
