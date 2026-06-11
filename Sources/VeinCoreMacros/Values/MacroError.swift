public enum MacroError: Error {
    case onlyApplicableToClasses
    case noIDVariable
    case relationshipKeypathDoesNotMatchTypeDeclaration(String)
}
