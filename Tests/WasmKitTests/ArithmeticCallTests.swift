import Testing
import WAT
@_spi(OnlyForCLI) @testable import WasmKit

@Suite struct ArithmeticCallTests {
    @Test(arguments: [EngineConfiguration.ThreadingModel.direct, .token])
    func exactBodiesAndInstrumentedFallback(threadingModel: EngineConfiguration.ThreadingModel) throws {
        for mode in [EngineConfiguration.CompilationMode.lazy, .eager] {
            for metered in [false, true] {
                for sideEffect in [false, true] {
                    let extra = sideEffect ? "i64.const 9 global.set $seen" : ""
                    let module = try parseWasm(bytes: wat2wasm("""
                        (module (global $seen (mut i64) (i64.const 0))
                          (func $mix (param i64 i64) (result i64) (local i64)
                            \(extra)
                            local.get 0 local.get 1 i64.add local.set 2
                            local.get 2 local.get 2 i64.const 17 i64.shr_u i64.xor
                            i64.const -4658895280553007687 i64.mul local.set 2
                            local.get 2 local.get 2 i64.const 27 i64.shr_u i64.xor
                            i64.const -7723592293110705685 i64.mul local.set 2
                            local.get 2 local.get 2 i64.const 31 i64.shr_u i64.xor)
                          (func (export "run") (param i64 i64) (result i64)
                            local.get 0 local.get 1 call $mix)
                          (func (export "seen") (result i64) global.get $seen))
                        """))
                    let store = Store(engine: Engine(configuration: .init(
                        threadingModel: threadingModel, compilationMode: mode, fuelMetering: metered)))
                    if metered { store.fuel = Fuel(remaining: 1_000_000) }
                    let instance = try module.instantiate(store: store)
                    let run = try #require(instance.exports[function: "run"])
                    for x: UInt64 in [0, 1, .max, 0x8000000000000000, 0x123456789abcdef0] {
                        for salt: UInt64 in [0, 1, .max] {
                            let sum = x &+ salt
                            let first = (sum ^ (sum &>> 17)) &* 0xbf58476d1ce4e5b9
                            let second = (first ^ (first &>> 27)) &* 0x94d049bb133111eb
                            #expect(try run([.i64(x), .i64(salt)]) == [.i64(second ^ (second &>> 31))])
                        }
                    }
                    #expect(try instance.exports[function: "seen"]!([]) == [.i64(sideEffect ? 9 : 0)])
                    if metered { #expect(try #require(store.fuel).remaining < 1_000_000) }
                    let caller = instance.handle.functions[1]
                    let (body, _) = caller.assumeCompiled()
                    let zero = VReg(slotIndex: 0)
                    let expected = Instruction.internalCopy2ArithmeticCall(.init(
                        source0: zero, dest0: zero, source1: zero, dest1: zero,
                        rawCallee: 0, arguments: zero, spAddend: LVReg(zero)))
                    #expect((body.instructions[0] == expected.headSlotInline(threadingModel: threadingModel)) ==
                        (threadingModel == .direct && !metered && !sideEffect))
                }
            }
        }
    }
}
