import UIKit
import Darkmagicmobile
import Darwin

final class PerformanceOverlay: UILabel {
    private var timer: Timer?

    init() {
        super.init(frame: .zero)
        isHidden = true
        isUserInteractionEnabled = false
        accessibilityIdentifier = "developer.performance-overlay"
        font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        textColor = UIColor(red: 0.7, green: 1, blue: 0.6, alpha: 1)
        backgroundColor = UIColor.black.withAlphaComponent(0.8)
        adjustsFontSizeToFitWidth = true
        minimumScaleFactor = 0.75
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setEnabled(_ enabled: Bool) {
        guard enabled == isHidden else { return }
        timer?.invalidate()
        timer = nil
        isHidden = !enabled
        DarkmagicmobileSetPerformanceOverlayEnabled(enabled)
        guard enabled else { return }
        refresh()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func refresh() {
        let memory = Self.memoryFootprint().map { String(format: "RAM %.0f MiB", $0) } ?? "RAM unavailable"
        let thermal: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = "nominal"
        case .fair: thermal = "fair"
        case .serious: thermal = "serious"
        case .critical: thermal = "critical"
        @unknown default: thermal = "unknown"
        }
        text = "  \(DarkmagicmobilePerformanceSummary()) | \(memory) | thermal \(thermal)  "
    }

    private static func memoryFootprint() -> Double? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let capacity = Int(count)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        let requiredBytes = MemoryLayout.offset(of: \task_vm_info_data_t.phys_footprint)! + MemoryLayout<mach_vm_size_t>.size
        guard result == KERN_SUCCESS, Int(count) * MemoryLayout<integer_t>.size >= requiredBytes else { return nil }
        return Double(info.phys_footprint) / 1_048_576
    }

    deinit { timer?.invalidate() }
}
