import Foundation
import IOKit
import IOKit.hid

final class Accelerometer {
    private var device: IOHIDDevice?
    private var reportBuffer: UnsafeMutablePointer<UInt8>?
    private var callbackRef: IOHIDReportCallback?
    private var smoothedX: Double = 0
    private var smoothedY: Double = 0
    private var smoothedZ: Double = 0
    private let alpha: Double = 0.15
    private let lock = NSLock()
    private var sensorThread: Thread?
    private(set) var isAvailable = false

    var gravity: (x: Double, y: Double) {
        lock.lock()
        defer { lock.unlock() }
        return (smoothedX, smoothedY)
    }

    func start() {
        sensorThread = Thread { [weak self] in
            guard let self else { return }
            if self.setupSensor() {
                self.isAvailable = true
                CFRunLoopRun()
            }
        }
        sensorThread?.name = "Accelerometer"
        sensorThread?.start()

        // Give the sensor thread time to initialize
        Thread.sleep(forTimeInterval: 0.2)
    }

    private func setupSensor() -> Bool {
        wakeSPUDrivers()

        guard let (dev, buf) = findAndOpenAccelDevice() else { return false }
        self.device = dev
        self.reportBuffer = buf

        let context = Unmanaged.passUnretained(self).toOpaque()

        IOHIDDeviceRegisterInputReportCallback(
            dev,
            buf,
            4096,
            { context, result, sender, type, reportID, report, length in
                guard length == 22, let ctx = context else { return }
                let accel = Unmanaged<Accelerometer>.fromOpaque(ctx).takeUnretainedValue()

                let x = readInt32LE(report, offset: 6)
                let y = readInt32LE(report, offset: 10)
                let z = readInt32LE(report, offset: 14)

                let xG = Double(x) / 65536.0
                let yG = Double(y) / 65536.0
                let zG = Double(z) / 65536.0

                accel.lock.lock()
                accel.smoothedX += accel.alpha * (xG - accel.smoothedX)
                accel.smoothedY += accel.alpha * (yG - accel.smoothedY)
                accel.smoothedZ += accel.alpha * (zG - accel.smoothedZ)
                accel.lock.unlock()
            },
            context
        )

        IOHIDDeviceScheduleWithRunLoop(dev, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        return true
    }

    private func wakeSPUDrivers() {
        guard let matching = IOServiceMatching("AppleSPUHIDDriver") else { return }
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else { return }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            let keys = ["SensorPropertyReportingState", "SensorPropertyPowerState", "ReportInterval"]
            let values: [CFNumber] = [1 as CFNumber, 1 as CFNumber, 1000 as CFNumber]
            for (key, value) in zip(keys, values) {
                IORegistryEntrySetCFProperty(service, key as CFString, value)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)
    }

    private func findAndOpenAccelDevice() -> (IOHIDDevice, UnsafeMutablePointer<UInt8>)? {
        guard let matching = IOServiceMatching("AppleSPUHIDDevice") else { return nil }
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else { return nil }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            let usagePage = registryPropertyInt(service, key: "PrimaryUsagePage") ?? 0
            let usage = registryPropertyInt(service, key: "PrimaryUsage") ?? 0

            if usagePage == 0xFF00 && usage == 3 {
                if let hidDevice = IOHIDDeviceCreate(kCFAllocatorDefault, service) {
                    let openResult = IOHIDDeviceOpen(hidDevice, IOOptionBits(kIOHIDOptionsTypeNone))
                    if openResult == kIOReturnSuccess {
                        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
                        buf.initialize(repeating: 0, count: 4096)
                        IOObjectRelease(service)
                        IOObjectRelease(iterator)
                        return (hidDevice, buf)
                    }
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)
        return nil
    }

    private func registryPropertyInt(_ entry: io_registry_entry_t, key: String) -> Int? {
        guard let cf = IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        let value = cf.takeRetainedValue()
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }

    deinit {
        reportBuffer?.deallocate()
    }
}

private func readInt32LE(_ ptr: UnsafeMutablePointer<UInt8>, offset: Int) -> Int32 {
    let p = ptr.advanced(by: offset)
    return Int32(p[0]) | (Int32(p[1]) << 8) | (Int32(p[2]) << 16) | (Int32(p[3]) << 24)
}
