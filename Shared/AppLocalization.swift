import Foundation

enum AppLocalization {
    private final class BundleToken: NSObject {}

    private static let appBundle = Bundle(for: BundleToken.self)

    static func string(_ key: String, language: AppLanguage) -> String {
        localizedBundle(for: language).localizedString(
            forKey: key,
            value: key,
            table: "Localizable"
        )
    }

    static func format(
        _ key: String,
        language: AppLanguage,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: string(key, language: language),
            locale: language.locale,
            arguments: arguments
        )
    }

    private static func localizedBundle(for language: AppLanguage) -> Bundle {
        guard
            let path = appBundle.path(
                forResource: language.localizationResourceName,
                ofType: "lproj"
            ),
            let bundle = Bundle(path: path)
        else {
            return appBundle
        }

        return bundle
    }
}

extension AppLanguage {
    var locale: Locale {
        Locale(identifier: rawValue)
    }

    fileprivate var localizationResourceName: String {
        switch self {
        case .korean:
            "ko"
        case .english:
            "en"
        }
    }
}
