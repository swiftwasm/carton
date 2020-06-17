import Danger

SwiftLint.lint(inline: true, configFile: ".swiftlint.yml", strict: true)

let danger = Danger()

print("Calling SwiftFormat...")

danger.utils.exec("swiftformat", arguments: ["."])
