import Foundation

/// Protocol for controlling a smart trainer.
/// Implementations: FTMSAdapter (standard), TacxAdapter (proprietary fallback).
/// Chosen at runtime via capability discovery on first BLE connect.
protocol TrainerControl: Actor {
    /// ERG mode: hold exactly this power regardless of cadence.
    func setTargetPower(_ watts: Int) async throws

    /// SIM mode: simulate climbing/descending at the given grade.
    /// - Parameters:
    ///   - grade: road gradient in percent (negative = downhill).
    ///   - totalWeight: combined rider + bike weight in kg.
    func setSimulation(grade: Double, totalWeight: Double) async throws

    func disconnect() async
}
