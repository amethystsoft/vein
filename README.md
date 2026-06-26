# Amethyst Vein

## Roadmap to 1.0
- Take a look at currently open issues

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
