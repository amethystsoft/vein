import Vein
#if os(Linux)
let globalInit: Void = {
    Keyring.appIdentifier.withLock { identifier in
        identifier = "de.amethystsoft.vein.tests"
    }
}()
#endif
