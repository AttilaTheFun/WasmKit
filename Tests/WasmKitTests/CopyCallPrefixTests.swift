import Testing
import WAT
@_spi(OnlyForCLI) @testable import WasmKit

@Suite struct CopyCallPrefixTests {
    @Test(arguments: [EngineConfiguration.ThreadingModel.direct, .token])
    func preservesArgumentOrderAndLargeFrames(threadingModel: EngineConfiguration.ThreadingModel) throws {
        let expression = "local.get 0 i64.const 3 i64.mul local.get 1 i64.add i64.const 5 i64.mul local.get 2 i64.add i64.const 7 i64.mul local.get 3 i64.add"
        let reversed = "local.get 3 local.get 2 local.get 1 local.get 0"
        let locals = Array(repeating: "i64", count: 70).joined(separator: " ")
        let module = try parseWasm(bytes: wat2wasm("""
            (module
              (func $tri (param i64 i64 i64) (result i64)
                local.get 0 local.get 1 i64.sub local.get 2 i64.sub)
              (func $quad (param i64 i64 i64 i64) (result i64) \(expression))
              (func $large (param i64 i64 i64 i64) (result i64) (local \(locals))
                \(expression) local.get 73 i64.add)
              (func (export "three") (param i64 i64 i64) (result i64)
                local.get 2 local.get 1 local.get 0 call $tri)
              (func (export "four") (param i64 i64 i64 i64) (result i64)
                \(reversed) call $quad)
              (func (export "large") (param i64 i64 i64 i64) (result i64)
                \(reversed) call $large)
              (func (export "branch") (param i64 i64 i64 i64 i32) (result i64)
                local.get 4 if (result i64)
                  \(reversed) call $quad
                else i64.const 7 end))
            """))
        for mode in [EngineConfiguration.CompilationMode.lazy, .eager] {
            let store = Store(engine: Engine(configuration: .init(threadingModel: threadingModel, compilationMode: mode)))
            let instance = try module.instantiate(store: store)
            let three = try #require(instance.exports[function: "three"])
            let four = try #require(instance.exports[function: "four"])
            let large = try #require(instance.exports[function: "large"])
            let branch = try #require(instance.exports[function: "branch"])
            for x: UInt64 in [0, 1, 17, .max] {
                let args: [Value] = [.i64(x), .i64(11), .i64(23), .i64(31)]
                let expected = (((UInt64(31) &* 3 &+ 23) &* 5 &+ 11) &* 7) &+ x
                #expect(try three(Array(args.prefix(3))) == [.i64(23 &- 11 &- x)])
                #expect(try four(args) == [.i64(expected)])
                #expect(try large(args) == [.i64(expected)])
                #expect(try branch(args + [.i32(1)]) == [.i64(expected)])
                #expect(try branch(args + [.i32(0)]) == [.i64(7)])
            }
        }
        #if Disassembler
        if threadingModel == .direct {
            let store = Store(engine: Engine(configuration: .init(threadingModel: threadingModel)))
            let instance = try module.instantiate(store: store)
            var listing = ""
            try instance.dumpFunctions(to: &listing, module: module)
            #expect(listing.contains("compilingCopy3Call"))
            #expect(listing.contains("compilingCopy4Call"))
        }
        #endif
    }
}
