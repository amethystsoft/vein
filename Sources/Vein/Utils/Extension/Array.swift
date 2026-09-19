extension Array where Element: PersistentModel {
    var asIDDictionary: [ULID: Element] {
        var dictionary = [ULID: Element]()
        
        for element in self {
            dictionary[element.id] = element
        }
        
        return dictionary
    }
}
