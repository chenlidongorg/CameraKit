import Foundation

enum CameraKitLocalization {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: .module, comment: key)
    }
}
