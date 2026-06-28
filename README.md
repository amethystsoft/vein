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

### Third-Party-Licenses
Licenses of third party projects are in the Acknowledgements folder.
* **Vein** contains a modified copy of [yaslab/ULID.swift](https://github.com/yaslab/ULID.swift.git).
  The original MIT license can be found in [Acknowledgements/ULID-LICENSE](./Acknowledgements/yaslab ULID.swift/LICENSE).