#if canImport(WinSDK)
@testable import Vein
import Testing

@Suite
struct WinCredentialTest {
	@Test
	func ensureEncodeDecode() async throws {
		let ressource = "de.amethystsoft.vein.WinCredentialTest"
		let username = "VeinCredentialTest"
		let secret = "test123-"
		
		WinCredential.store(
			ressource: ressource,
			username: username,
			secret: secret
		)
		
		let result = WinCredential.retrieve(ressource: ressource)
		
		#expect(secret == result)
	}
}
#endif