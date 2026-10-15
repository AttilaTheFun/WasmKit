import Testing
import WAT
@testable import WasmKit

@Suite struct InternalCallFrameTests {
    @Test(arguments: [EngineConfiguration.ThreadingModel.direct, .token])
    func frameSizesAndRepeatedCalls(threadingModel: EngineConfiguration.ThreadingModel) throws {
        for count in [0, 1, 2, 4, 8, 15, 16, 17, 31, 32, 33, 63, 64, 65, 100] {
            let locals = count == 0 ? "" : "(local " + Array(repeating: "i64", count: count).joined(separator: " ") + ")"
            let check = count == 0 ? "i64.const 0" : (1...count).map { "local.get \($0)" }.joined(separator: " ") + String(repeating: " i64.or", count: count - 1)
            let dirty = count == 0 ? "" : (1...count).map { "local.get 0 local.set \($0)" }.joined(separator: " ")
            let module = try parseWasm(bytes: wat2wasm("""
                (module
                  (func $callee (param i64) (result i64) \(locals)
                    local.get 0 \(check) i64.add \(dirty))
                  (func (export "run") (param i64) (result i64)
                    local.get 0 call $callee call $callee))
                """))
            for mode in [EngineConfiguration.CompilationMode.lazy, .eager] {
                let store = Store(engine: Engine(configuration: .init(threadingModel: threadingModel, compilationMode: mode)))
                let instance = try module.instantiate(store: store)
                let run = try #require(instance.exports[function: "run"])
                for value in UInt64(1)...10 { #expect(try run([.i64(value)]) == [.i64(value)]) }
            }
        }
    }
    #if WasmDebuggingSupport
    @Test(arguments: [EngineConfiguration.ThreadingModel.direct, .token])
    func debuggerStepsAcrossMediumFrameCalls(threadingModel: EngineConfiguration.ThreadingModel) throws {
        let locals = Array(repeating: "i64", count: 24).joined(separator: " ")
        let module = try parseWasm(bytes: wat2wasm("""
            (module
              (func $callee (result i32) (local \(locals)) i32.const 42)
              (func (export "_start") (result i32) call $callee drop call $callee))
            """))
        let store = Store(engine: Engine(configuration: .init(threadingModel: threadingModel)))
        var debugger = try Debugger(module: module, store: store, imports: [:])
        try debugger.stopAtEntrypoint()
        try debugger.run()
        for _ in 0..<100 {
            if case .entrypointReturned(let values) = debugger.state {
                #expect(values == [.i32(42)])
                return
            }
            try debugger.step()
        }
        Issue.record("Stepping did not return from the repeated medium-frame call")
    }
    #endif

}
