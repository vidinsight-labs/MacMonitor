import Foundation
import Security

/// Security.framework ile kod imzası durumu okuma (sandbox uyumlu).
enum CodeSigningHelper {

    static func signingStatus(of path: String) -> Signing {
        guard FileManager.default.fileExists(atPath: path) else { return .unknown }

        var staticCode: SecStaticCode?
        let url = URL(fileURLWithPath: path) as CFURL
        guard SecStaticCodeCreateWithPath(url, [], &staticCode) == errSecSuccess,
              let code = staticCode
        else { return .unknown }

        var infoCF: CFDictionary?
        let copyResult = SecCodeCopySigningInformation(
            code, SecCSFlags(rawValue: kSecCSSigningInformation), &infoCF
        )
        let info = infoCF as? [String: Any]

        if copyResult == errSecCSUnsigned {
            return .unsigned
        }

        if let certs = info?[kSecCodeInfoCertificates as String] as? [SecCertificate],
           let leaf = certs.first {
            if let summary = certificateSummary(leaf) {
                if summary.contains("Apple") || summary == "Software Signing" {
                    return .apple
                }
                if summary.hasPrefix("Developer ID Application: ") {
                    let rest = summary.dropFirst("Developer ID Application: ".count)
                    let name = rest.components(separatedBy: " (").first ?? String(rest)
                    return .developer(name)
                }
                return .developer(summary)
            }
        }

        if let team = info?[kSecCodeInfoTeamIdentifier as String] as? String, !team.isEmpty {
            return .developer(team)
        }

        let validity = SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), nil)
        if validity == errSecSuccess {
            return .apple
        }
        if validity == errSecCSUnsigned {
            return .unsigned
        }

        return .unknown
    }

    private static func certificateSummary(_ cert: SecCertificate) -> String? {
        var commonName: CFString?
        SecCertificateCopyCommonName(cert, &commonName)
        return commonName as String?
    }
}
