import Danger

let danger = Danger()

print("Calling SwiftFormat...")

danger.utils.exec("swiftformat", arguments: ["."])
