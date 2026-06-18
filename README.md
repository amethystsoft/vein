# Amethyst Vein

## Roadmap to 1.0
[ ] Support plugging in a logger for better debug experience
[ ] Documentation. Loads of documentation and tutorials.
[ ] Generate fields that will be required by sync solutions in 2.0 to avoid annoying migrations
[ ] fix testing on release build
[ ] Resolve remaining issues

If using encryption on Linux, set app identifier before using model context
```swift
#if os(Linux)
    import Vein
    
    Keyring.appIdentifier.withLock { identifier in
        identifier = "com.example.yourapp"
    }
#endif
```

To disable encryption for Vein unit tests and VeinTesting set
`SHOULD_DISABLE_ENCRYPTION=1`
in your environment
