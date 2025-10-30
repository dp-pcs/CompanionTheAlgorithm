import Foundation
import Security

class CookieManager {
    
    private let keychainService = "TheAlgorithm"
    private let cookiesAccount = "twitter_cookies"
    
        // MARK: - Cookie Storage
    
    func storeCookies(_ cookies: [HTTPCookie]) {
        let cookieData = cookies.compactMap { cookie in
            return [
                "name": cookie.name,
                "value": cookie.value,
                "domain": cookie.domain,
                "path": cookie.path,
                "expires": cookie.expiresDate?.timeIntervalSince1970 ?? 0,
                "httpOnly": cookie.isHTTPOnly,
                "secure": cookie.isSecure,
                "sameSite": cookie.sameSitePolicy?.rawValue ?? ""
            ]
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: cookieData, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            
            KeychainHelper.save(jsonString, service: keychainService, account: cookiesAccount)
            
            print("✅ Stored \(cookies.count) cookies securely")
            logCookieDetails(cookies)
            
        } catch {
            print("❌ Failed to serialize cookies: \(error)")
        }
    }
    
    func getStoredCookies() -> [HTTPCookie]? {
        guard let jsonString = KeychainHelper.read(service: keychainService, account: cookiesAccount),
              let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        
        do {
            guard let cookieDataArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
                return nil
            }
            
            let cookies = cookieDataArray.compactMap { cookieData -> HTTPCookie? in
                guard let name = cookieData["name"] as? String,
                      let value = cookieData["value"] as? String,
                      let domain = cookieData["domain"] as? String,
                      let path = cookieData["path"] as? String else {
                    return nil
                }
                
                var properties: [HTTPCookiePropertyKey: Any] = [
                    .name: name,
                    .value: value,
                    .domain: domain,
                    .path: path
                ]
                
                if let expires = cookieData["expires"] as? TimeInterval, expires > 0 {
                    properties[.expires] = Date(timeIntervalSince1970: expires)
                }
                
                if let httpOnly = cookieData["httpOnly"] as? Bool, httpOnly {
                    properties[.init("HttpOnly")] = "TRUE"
                }
                
                if let secure = cookieData["secure"] as? Bool, secure {
                    properties[.secure] = "TRUE"
                }
                
                if let sameSite = cookieData["sameSite"] as? String, !sameSite.isEmpty {
                    properties[.sameSitePolicy] = sameSite
                }
                
                return HTTPCookie(properties: properties)
            }
            
            return cookies
            
        } catch {
            print("❌ Failed to deserialize cookies: \(error)")
            return nil
        }
    }
    
    func hasValidCookies() -> Bool {
        guard let cookies = getStoredCookies() else {
            return false
        }
        
            // Check if we have essential Twitter cookies
        let essentialCookies = ["auth_token", "ct0"]
        let cookieNames = Set(cookies.map { $0.name })
        let hasEssential = essentialCookies.allSatisfy { cookieNames.contains($0) }
        
            // Check if cookies are not expired
        let now = Date()
        let hasValidCookies = cookies.allSatisfy { cookie in
            guard let expiresDate = cookie.expiresDate else { return true } // Session cookies are OK
            return expiresDate > now
        }
        
        return hasEssential && hasValidCookies
    }
    
    func clearCookies() {
        KeychainHelper.delete(service: keychainService, account: cookiesAccount)
        print("🗑️ Cleared stored cookies")
    }
    
        // MARK: - Cookie Validation
    
    func validateCookies(_ cookies: [HTTPCookie]) -> CookieValidationResult {
        let cookieNames = Set(cookies.map { $0.name })
        let domains = Set(cookies.map { $0.domain })
        
            // Check for essential cookies
        let essentialCookies = ["auth_token", "ct0"]
        let missingEssential = essentialCookies.filter { !cookieNames.contains($0) }
        
            // Check for common optional cookies
        let optionalCookies = ["auth_multi", "twid", "kdt", "remember_checked_on"]
        let presentOptional = optionalCookies.filter { cookieNames.contains($0) }
        
            // Check domains
        let validDomains = domains.contains { $0.contains("x.com") || $0.contains("twitter.com") }
        
            // Check expiration
        let now = Date()
        let expiredCookies = cookies.filter { cookie in
            guard let expiresDate = cookie.expiresDate else { return false }
            return expiresDate <= now
        }
        
        return CookieValidationResult(
            isValid: missingEssential.isEmpty && validDomains && expiredCookies.isEmpty,
            essentialCookies: essentialCookies.filter { cookieNames.contains($0) },
            missingEssentialCookies: missingEssential,
            optionalCookies: presentOptional,
            expiredCookies: expiredCookies.map { $0.name },
            totalCount: cookies.count
        )
    }
    
        // MARK: - Utility Methods
    
    private func logCookieDetails(_ cookies: [HTTPCookie]) {
        print("\n📋 Cookie Details:")
        for cookie in cookies {
            let expiresStr = cookie.expiresDate?.description ?? "Session"
            print("  • \(cookie.name): \(cookie.value.prefix(20))... (expires: \(expiresStr))")
        }
        print("")
    }
    
    func getCookiesSummary() -> String? {
        guard let cookies = getStoredCookies() else {
            return "No cookies stored"
        }
        
        let validation = validateCookies(cookies)
        
        var summary = "🍪 Cookies Summary:\n"
        summary += "Total: \(validation.totalCount)\n"
        summary += "Essential: \(validation.essentialCookies.joined(separator: ", "))\n"
        
        if !validation.missingEssentialCookies.isEmpty {
            summary += "❌ Missing: \(validation.missingEssentialCookies.joined(separator: ", "))\n"
        }
        
        if !validation.optionalCookies.isEmpty {
            summary += "Optional: \(validation.optionalCookies.joined(separator: ", "))\n"
        }
        
        if !validation.expiredCookies.isEmpty {
            summary += "⚠️ Expired: \(validation.expiredCookies.joined(separator: ", "))\n"
        }
        
        summary += "Status: \(validation.isValid ? "✅ Valid" : "❌ Invalid")"
        
        return summary
    }
}

    // MARK: - Cookie Validation Result

struct CookieValidationResult {
    let isValid: Bool
    let essentialCookies: [String]
    let missingEssentialCookies: [String]
    let optionalCookies: [String]
    let expiredCookies: [String]
    let totalCount: Int
}

    // MARK: - HTTPCookie Extensions

extension HTTPCookie {
    
    var customDebugDescription: String {
        var desc = "\(name)=\(value)"
        desc += "; Domain=\(domain)"
        desc += "; Path=\(path)"
        
        if let expires = expiresDate {
            desc += "; Expires=\(expires)"
        }
        
        if isSecure {
            desc += "; Secure"
        }
        
        if isHTTPOnly {
            desc += "; HttpOnly"
        }
        
        if let sameSite = sameSitePolicy {
            desc += "; SameSite=\(sameSite.rawValue)"
        }
        
        return desc
    }
    
    var isExpired: Bool {
        guard let expiresDate = expiresDate else {
            return false // Session cookies don't expire
        }
        return expiresDate <= Date()
    }
    
    var isTwitterCookie: Bool {
        let domain = self.domain.lowercased()
        return domain.contains("x.com") || domain.contains("twitter.com")
    }
}

    // MARK: - Cookie Dictionary Conversion

extension Array where Element == HTTPCookie {
    
    func toDictionary() -> [String: String] {
        return reduce(into: [String: String]()) { result, cookie in
            result[cookie.name] = cookie.value
        }
    }
    
    func toNetworkCookieString() -> String {
        return map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }
}
