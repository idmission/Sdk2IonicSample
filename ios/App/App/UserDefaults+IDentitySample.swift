//
//  UserDefaults+IDentitySample.swift
//  IDentitySample
//
//  Created by Stefan Kaczmarek on 10/23/21.
//

import Foundation
import Security
import IDentitySDK_Swift

struct ServiceOptions: Codable {
    enum ManualReviewRequired: Int, Codable {
        case yes, no, forced
    }

    var manualReviewRequired: ManualReviewRequired
    var bypassAgeValidation: Bool
    var deDuplicationRequired: Bool
    var bypassNameMatching: Bool
    var postDataAPIRequired: Bool
    var sendInputImagesInPost: Bool
    var sendProcessedImagesInPost: Bool
    var needImmediateResponse: Bool
    var deduplicationSynchronous: Bool
    var verifyDataWithHost: Bool
    var idBackImageRequired: Bool
    var stripSpecialCharacters: Bool

    static var `default`: ServiceOptions {
        ServiceOptions(manualReviewRequired: .no,
                       bypassAgeValidation: false,
                       deDuplicationRequired: false,
                       bypassNameMatching: true,
                       postDataAPIRequired: false,
                       sendInputImagesInPost: false,
                       sendProcessedImagesInPost: false,
                       needImmediateResponse: false,
                       deduplicationSynchronous: false,
                       verifyDataWithHost: false,
                       idBackImageRequired: true,
                       stripSpecialCharacters: true)
    }
}

extension UserDefaults {
    static let defaultTemplateModelBaseURL = "https://demo.idmission.com/IDS/service/"
    static let defaultAPIBaseURL = "https://apidemo.idmission.com/"

    static let defaultLoginId = ""
    static let defaultPassword = ""
    static let defaultMerchantId = ""

    private static let templateModelBaseURLKey = "templateModelBaseURL"
    static var templateModelBaseURL: String {
        get { standard.string(forKey: templateModelBaseURLKey) ?? defaultTemplateModelBaseURL }
        set { standard.set(newValue, forKey: templateModelBaseURLKey) }
    }

    private static let apiBaseURLKey = "apiBaseURL"
    static var apiBaseURL: String {
        get { standard.string(forKey: apiBaseURLKey) ?? defaultAPIBaseURL }
        set { standard.set(newValue, forKey: apiBaseURLKey) }
    }

    // Credentials are sensitive and are stored in the Keychain, not in UserDefaults (CWE-311).
    private static let loginIdKey = "loginId"
    static var loginId: String {
        get { CredentialStore.read(loginIdKey) ?? defaultLoginId }
        set { CredentialStore.write(newValue, for: loginIdKey) }
    }

    private static let passwordKey = "password"
    static var password: String {
        get { CredentialStore.read(passwordKey) ?? defaultPassword }
        set { CredentialStore.write(newValue, for: passwordKey) }
    }

    private static let merchantIdKey = "merchantId"
    static var merchantId: String {
        get { CredentialStore.read(merchantIdKey) ?? defaultMerchantId }
        set { CredentialStore.write(newValue, for: merchantIdKey) }
    }

    /// Removes any credentials persisted in plain text by earlier versions of the app.
    static func purgeLegacyCredentials() {
        for key in [loginIdKey, passwordKey, merchantIdKey] {
            standard.removeObject(forKey: key)
        }
    }

    // MARK: - Service Options

    private static let serviceOptionsKey = "serviceOptions"
    static var serviceOptions: ServiceOptions {
        get {
            if let data = standard.data(forKey: serviceOptionsKey),
                let options = try? JSONDecoder().decode(ServiceOptions.self, from: data) {
                return options
            } else {
                return .default
            }
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            standard.set(data, forKey: serviceOptionsKey)
        }
    }

    // MARK: -

    private static let debugModeKey = "debugMode"
    static var debugMode: Bool {
        get { standard.bool(forKey: debugModeKey) }
        set { standard.set(newValue, forKey: debugModeKey) }
    }

    private static let capture4KKey = "capture4K"
    static var capture4K: Bool {
        get { standard.bool(forKey: capture4KKey) }
        set { standard.set(newValue, forKey: capture4KKey) }
    }
}

// MARK: - Keychain-backed credential storage

enum CredentialStore {
    private static let service = (Bundle.main.bundleIdentifier ?? "io.ionic.starter") + ".credentials"

    private static func baseQuery(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }

    static func read(_ key: String) -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String, for key: String) {
        let query = baseQuery(key)
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty, let data = value.data(using: .utf8) else { return }
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
