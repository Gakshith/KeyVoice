import Foundation
import os

/// One tiny logger so every stage is traceable when reviewing/debugging.
public enum Log {
    private static let logger = Logger(subsystem: "com.keyvoice.app", category: "pipeline")

    public static func info(_ msg: String)  { logger.info("\(msg, privacy: .public)") }
    public static func warn(_ msg: String)  { logger.warning("\(msg, privacy: .public)") }
    public static func error(_ msg: String) { logger.error("\(msg, privacy: .public)") }
}
