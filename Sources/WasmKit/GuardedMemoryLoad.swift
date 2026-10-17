/// Minimum offset reservation for every shared memory, independent of which
/// engine imports it. Shared memories have no malloc fallback and are wasm32.
/// For an index <= UInt32.max and offset + width <= this size, every byte of
/// the load is inside the reservation. Uncommitted bytes fault into the trap guard.
enum Memory32GuardedLoad {
    static let offsetGuardSize = 64 * 1024
}

extension Instruction {
    /// Only called while translating an access to shared memory zero. Operand
    /// layouts are identical, so rewriting a head preserves relinking/fusion.
    func guardedMemoryLoad() -> Instruction? {
        switch self {
        case .i32Load(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .i32LoadGuarded(operand)
        case .i32LoadToAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .i32LoadToAccGuarded(operand)
        case .i32LoadFromAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .i32LoadFromAccGuarded(operand)
        case .i32LoadInAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .i32LoadInAccGuarded(operand)
        case .i32LoadToAccAndSlot(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .i32LoadToAccAndSlotGuarded(operand)
        case .i32LoadWithCopy(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .i32LoadWithCopyGuarded(operand)
        case .i64Load(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 8):
            return .i64LoadGuarded(operand)
        case .i64LoadToAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 8):
            return .i64LoadToAccGuarded(operand)
        case .i64LoadFromAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 8):
            return .i64LoadFromAccGuarded(operand)
        case .i64LoadInAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 8):
            return .i64LoadInAccGuarded(operand)
        case .i64LoadToAccAndSlot(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 8):
            return .i64LoadToAccAndSlotGuarded(operand)
        case .i64LoadWithCopy(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 8):
            return .i64LoadWithCopyGuarded(operand)
        case .f32Load(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .f32LoadGuarded(operand)
        case .f32LoadToAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .f32LoadToAccGuarded(operand)
        case .f32LoadFromAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .f32LoadFromAccGuarded(operand)
        case .f32LoadInAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .f32LoadInAccGuarded(operand)
        case .f32LoadToAccAndSlot(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .f32LoadToAccAndSlotGuarded(operand)
        case .f32LoadWithCopy(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .f32LoadWithCopyGuarded(operand)
        case .f64Load(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 8):
            return .f64LoadGuarded(operand)
        case .f64LoadToAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 8):
            return .f64LoadToAccGuarded(operand)
        case .f64LoadFromAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 8):
            return .f64LoadFromAccGuarded(operand)
        case .f64LoadInAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 8):
            return .f64LoadInAccGuarded(operand)
        case .f64LoadToAccAndSlot(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 8):
            return .f64LoadToAccAndSlotGuarded(operand)
        case .f64LoadWithCopy(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 8):
            return .f64LoadWithCopyGuarded(operand)
        case .i32Load8S(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i32Load8SGuarded(operand)
        case .i32Load8SToAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i32Load8SToAccGuarded(operand)
        case .i32Load8SFromAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i32Load8SFromAccGuarded(operand)
        case .i32Load8SInAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i32Load8SInAccGuarded(operand)
        case .i32Load8SToAccAndSlot(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i32Load8SToAccAndSlotGuarded(operand)
        case .i32Load8SWithCopy(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i32Load8SWithCopyGuarded(operand)
        case .i32Load8U(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i32Load8UGuarded(operand)
        case .i32Load8UToAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i32Load8UToAccGuarded(operand)
        case .i32Load8UFromAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i32Load8UFromAccGuarded(operand)
        case .i32Load8UInAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i32Load8UInAccGuarded(operand)
        case .i32Load8UToAccAndSlot(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i32Load8UToAccAndSlotGuarded(operand)
        case .i32Load8UWithCopy(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i32Load8UWithCopyGuarded(operand)
        case .i32Load16S(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i32Load16SGuarded(operand)
        case .i32Load16SToAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i32Load16SToAccGuarded(operand)
        case .i32Load16SFromAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i32Load16SFromAccGuarded(operand)
        case .i32Load16SInAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i32Load16SInAccGuarded(operand)
        case .i32Load16SToAccAndSlot(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i32Load16SToAccAndSlotGuarded(operand)
        case .i32Load16SWithCopy(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i32Load16SWithCopyGuarded(operand)
        case .i32Load16U(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i32Load16UGuarded(operand)
        case .i32Load16UToAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i32Load16UToAccGuarded(operand)
        case .i32Load16UFromAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i32Load16UFromAccGuarded(operand)
        case .i32Load16UInAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i32Load16UInAccGuarded(operand)
        case .i32Load16UToAccAndSlot(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i32Load16UToAccAndSlotGuarded(operand)
        case .i32Load16UWithCopy(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i32Load16UWithCopyGuarded(operand)
        case .i64Load8S(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i64Load8SGuarded(operand)
        case .i64Load8SToAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i64Load8SToAccGuarded(operand)
        case .i64Load8SFromAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i64Load8SFromAccGuarded(operand)
        case .i64Load8SInAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i64Load8SInAccGuarded(operand)
        case .i64Load8SToAccAndSlot(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i64Load8SToAccAndSlotGuarded(operand)
        case .i64Load8SWithCopy(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i64Load8SWithCopyGuarded(operand)
        case .i64Load8U(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i64Load8UGuarded(operand)
        case .i64Load8UToAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i64Load8UToAccGuarded(operand)
        case .i64Load8UFromAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i64Load8UFromAccGuarded(operand)
        case .i64Load8UInAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i64Load8UInAccGuarded(operand)
        case .i64Load8UToAccAndSlot(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i64Load8UToAccAndSlotGuarded(operand)
        case .i64Load8UWithCopy(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 1):
            return .i64Load8UWithCopyGuarded(operand)
        case .i64Load16S(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i64Load16SGuarded(operand)
        case .i64Load16SToAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i64Load16SToAccGuarded(operand)
        case .i64Load16SFromAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i64Load16SFromAccGuarded(operand)
        case .i64Load16SInAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i64Load16SInAccGuarded(operand)
        case .i64Load16SToAccAndSlot(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i64Load16SToAccAndSlotGuarded(operand)
        case .i64Load16SWithCopy(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i64Load16SWithCopyGuarded(operand)
        case .i64Load16U(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i64Load16UGuarded(operand)
        case .i64Load16UToAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i64Load16UToAccGuarded(operand)
        case .i64Load16UFromAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i64Load16UFromAccGuarded(operand)
        case .i64Load16UInAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i64Load16UInAccGuarded(operand)
        case .i64Load16UToAccAndSlot(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i64Load16UToAccAndSlotGuarded(operand)
        case .i64Load16UWithCopy(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 2):
            return .i64Load16UWithCopyGuarded(operand)
        case .i64Load32S(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .i64Load32SGuarded(operand)
        case .i64Load32SToAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .i64Load32SToAccGuarded(operand)
        case .i64Load32SFromAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .i64Load32SFromAccGuarded(operand)
        case .i64Load32SInAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .i64Load32SInAccGuarded(operand)
        case .i64Load32SToAccAndSlot(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .i64Load32SToAccAndSlotGuarded(operand)
        case .i64Load32SWithCopy(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .i64Load32SWithCopyGuarded(operand)
        case .i64Load32U(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .i64Load32UGuarded(operand)
        case .i64Load32UToAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .i64Load32UToAccGuarded(operand)
        case .i64Load32UFromAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .i64Load32UFromAccGuarded(operand)
        case .i64Load32UInAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .i64Load32UInAccGuarded(operand)
        case .i64Load32UToAccAndSlot(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .i64Load32UToAccAndSlotGuarded(operand)
        case .i64Load32UWithCopy(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .i64Load32UWithCopyGuarded(operand)
        case .i32LoadMemory32(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 4):
            return .i32LoadMemory32Guarded(operand)
        case .f64LoadToFAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 8):
            return .f64LoadToFAccGuarded(operand)
        case .f64LoadFromAccToFAcc(let operand) where UInt64(operand.offset) <= UInt64(Memory32GuardedLoad.offsetGuardSize - 8):
            return .f64LoadFromAccToFAccGuarded(operand)
        default: return nil
        }
    }
}
