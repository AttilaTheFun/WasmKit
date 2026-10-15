import Testing
import WAT
@testable import WasmKit

@Suite struct CopyFusionTests {
    // Multi-value branches move overlapping register ranges. Preserve sequential
    // copy semantics when grouping independent copies; never cross a join label.
    @Test(arguments: [EngineConfiguration.ThreadingModel.direct, .token])
    func overlappingBranchValues(threadingModel: EngineConfiguration.ThreadingModel) throws {
        let module = try parseWasm(bytes: wat2wasm("""
            (module
              (func (export "rotate") (param i32 i32 i32 i32 i32) (result i32 i32 i32 i32)
                (local i32)
                local.get 4
                local.set 5
                (loop $again (result i32 i32 i32 i32)
                  local.get 1
                  local.get 2
                  local.get 3
                  local.get 0
                  local.set 3
                  local.set 2
                  local.set 1
                  local.set 0
                  local.get 5
                  i32.const 1
                  i32.sub
                  local.tee 5
                  br_if $again
                  local.get 0
                  local.get 1
                  local.get 2
                  local.get 3))
              (func (export "join") (param i32 i32 i32 i32 i32) (result i32 i32 i32 i32)
                local.get 4
                (if (result i32 i32 i32 i32)
                  (then local.get 0 local.get 1 local.get 2 local.get 3)
                  (else local.get 3 local.get 2 local.get 1 local.get 0))))
            """))
        let store = Store(engine: Engine(configuration: .init(threadingModel: threadingModel)))
        let instance = try module.instantiate(store: store)
        let rotate = try #require(instance.exports[function: "rotate"])
        let join = try #require(instance.exports[function: "join"])
        let values: [Value] = [.i32(11), .i32(22), .i32(33), .i32(44)]
        for count in 1...12 {
            let offset = count % 4
            let expected = Array(values[offset...] + values[..<offset])
            #expect(try rotate(values + [.i32(UInt32(count))]) == expected)
        }
        #expect(try join(values + [.i32(1)]) == values)
        #expect(try join(values + [.i32(0)]) == Array(values.reversed()))
    }
}
