//
//  ErrorLogger.swift
//  EventFlow
//
//  Firebase Crashlytics統合によるエラーロギング
//  Requirements: 12.5
//

import Foundation
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

/// エラーロギングプロトコル
protocol ErrorLogging {
    func log(error: Error, context: [String: Any])
    func logMessage(_ message: String, level: LogLevel)
    func setUserId(_ userId: String?)
    func setCustomValue(_ value: Any?, forKey key: String)
}

/// ログレベル
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
}

/// Firebase Crashlyticsを使用したエラーロガー
class ErrorLogger: ErrorLogging {
    
    /// シングルトンインスタンス
    static let shared = ErrorLogger()
    
    private var crashlytics: Crashlytics? {
        #if canImport(FirebaseCrashlytics)
        return Crashlytics.crashlytics()
        #else
        return nil
        #endif
    }
    
    private init() {
        #if DEBUG
        print("📊 ErrorLogger initialized")
        #endif
    }
    
    // MARK: - ErrorLogging Protocol
    
    /// エラーをログに記録
    /// - Parameters:
    ///   - error: 記録するエラー
    ///   - context: エラーコンテキスト情報
    func log(error: Error, context: [String: Any] = [:]) {
        var logData: [String: Any] = [
            "error_type": String(describing: type(of: error)),
            "error_description": error.localizedDescription,
            "timestamp": Date().timeIntervalSince1970,
            "app_version": getAppVersion(),
            "os_version": getOSVersion()
        ]
        
        // EventFlowErrorの追加情報
        if let eventFlowError = error as? EventFlowError {
            logData["is_retryable"] = eventFlowError.isRetryable
            if let suggestion = eventFlowError.recoverySuggestion {
                logData["recovery_suggestion"] = suggestion
            }
        }
        
        // コンテキスト情報をマージ
        logData.merge(context) { (_, new) in new }
        
        // Firebase Crashlyticsに記録
        #if canImport(FirebaseCrashlytics)
        crashlytics?.record(error: error, userInfo: logData)
        
        // カスタムキーを設定
        for (key, value) in logData {
            crashlytics?.setCustomValue(value, forKey: key)
        }
        #endif
        
        // コンソールログ
        #if DEBUG
        print("🔴 Error logged:")
        print("  Type: \(logData["error_type"] ?? "unknown")")
        print("  Description: \(logData["error_description"] ?? "unknown")")
        if !context.isEmpty {
            print("  Context: \(context)")
        }
        #endif
        
        // ローカルログファイルにも記録（オプション）
        logToFile(logData)
    }
    
    /// メッセージをログに記録
    /// - Parameters:
    ///   - message: ログメッセージ
    ///   - level: ログレベル
    func logMessage(_ message: String, level: LogLevel = .info) {
        let logEntry = "[\(level.rawValue)] \(message)"
        
        #if canImport(FirebaseCrashlytics)
        crashlytics?.log(logEntry)
        #endif
        
        #if DEBUG
        let emoji = logLevelEmoji(for: level)
        print("\(emoji) \(logEntry)")
        #endif
        
        // ローカルログファイルにも記録
        logMessageToFile(logEntry, level: level)
    }
    
    /// ユーザーIDを設定
    /// - Parameter userId: ユーザーID（nilの場合はクリア）
    func setUserId(_ userId: String?) {
        #if canImport(FirebaseCrashlytics)
        crashlytics?.setUserID(userId)
        #endif
        
        #if DEBUG
        if let userId = userId {
            print("👤 User ID set: \(userId)")
        } else {
            print("👤 User ID cleared")
        }
        #endif
    }
    
    /// カスタム値を設定
    /// - Parameters:
    ///   - value: 設定する値
    ///   - key: キー
    func setCustomValue(_ value: Any?, forKey key: String) {
        #if canImport(FirebaseCrashlytics)
        crashlytics?.setCustomValue(value, forKey: key)
        #endif
        
        #if DEBUG
        print("🔧 Custom value set: \(key) = \(value ?? "nil")")
        #endif
    }
    
    // MARK: - Private Methods
    
    /// アプリバージョンを取得
    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        return "\(version) (\(build))"
    }
    
    /// OSバージョンを取得
    private func getOSVersion() -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
    }
    
    /// ログレベルに対応する絵文字を取得
    private func logLevelEmoji(for level: LogLevel) -> String {
        switch level {
        case .debug: return "🐛"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🔥"
        }
    }
    
    /// ローカルログファイルに記録
    private func logToFile(_ data: [String: Any]) {
        guard let logDirectory = getLogDirectory() else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "error_log_\(dateFormatter.string(from: Date())).json"
        let fileURL = logDirectory.appendingPathComponent(fileName)
        
        do {
            var existingLogs: [[String: Any]] = []
            
            // 既存のログを読み込み
            if FileManager.default.fileExists(atPath: fileURL.path),
               let existingData = try? Data(contentsOf: fileURL),
               let logs = try? JSONSerialization.jsonObject(with: existingData) as? [[String: Any]] {
                existingLogs = logs
            }
            
            // 新しいログを追加
            existingLogs.append(data)
            
            // ファイルに書き込み
            let jsonData = try JSONSerialization.data(withJSONObject: existingLogs, options: .prettyPrinted)
            try jsonData.write(to: fileURL)
            
        } catch {
            #if DEBUG
            print("⚠️ Failed to write log to file: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// メッセージをローカルログファイルに記録
    private func logMessageToFile(_ message: String, level: LogLevel) {
        guard let logDirectory = getLogDirectory() else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "message_log_\(dateFormatter.string(from: Date())).txt"
        let fileURL = logDirectory.appendingPathComponent(fileName)
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] \(message)\n"
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                fileHandle.seekToEndOfFile()
                if let data = logEntry.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                try logEntry.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            #if DEBUG
            print("⚠️ Failed to write message log to file: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// ログディレクトリを取得
    private func getLogDirectory() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        
        let logDirectory = documentsDirectory.appendingPathComponent("Logs")
        
        // ディレクトリが存在しない場合は作成
        if !FileManager.default.fileExists(atPath: logDirectory.path) {
            try? FileManager.default.createDirectory(
                at: logDirectory,
                withIntermediateDirectories: true
            )
        }
        
        return logDirectory
    }
    
    // MARK: - Log Management
    
    /// 古いログファイルを削除（7日以上前のログ）
    func cleanupOldLogs(olderThan days: Int = 7) {
        guard let logDirectory = getLogDirectory() else { return }
        
        let fileManager = FileManager.default
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        do {
            let files = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            for file in files {
                if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < cutoffDate {
                    try fileManager.removeItem(at: file)
                    
                    #if DEBUG
                    print("🗑️ Deleted old log file: \(file.lastPathComponent)")
                    #endif
                }
            }
        } catch {
            #if DEBUG
            print("⚠️ Failed to cleanup old logs: \(error.localizedDescription)")
            #endif
        }
    }
}
