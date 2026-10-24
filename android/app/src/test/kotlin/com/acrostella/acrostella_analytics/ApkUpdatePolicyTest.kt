package com.acrostella.acrostella_analytics

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class ApkUpdatePolicyTest {
    private val installed = ApkIdentity("com.acrostella.acrostella_analytics", 3, setOf("trusted"))

    @Test fun acceptsOnlyNewerMatchingPackageAndSigner() {
        ApkUpdatePolicy.validate(installed, installed.copy(version = 4), 4)
    }
    @Test fun rejectsDifferentPackage() {
        assertThrows(IllegalArgumentException::class.java) {
            ApkUpdatePolicy.validate(installed, installed.copy(packageName = "other", version = 4), 4)
        }
    }
    @Test fun rejectsDifferentOrMissingSigner() {
        for (signers in listOf(setOf("other"), emptySet())) {
            assertThrows(IllegalArgumentException::class.java) {
                ApkUpdatePolicy.validate(installed, installed.copy(version = 4, signers = signers), 4)
            }
        }
    }
    @Test fun rejectsDowngradesAndSameVersion() {
        for (version in listOf(2L, 3L)) {
            assertThrows(IllegalArgumentException::class.java) {
                ApkUpdatePolicy.validate(installed, installed.copy(version = version), version)
            }
        }
    }
    @Test fun rejectsManifestVersionMismatch() {
        assertThrows(IllegalArgumentException::class.java) {
            ApkUpdatePolicy.validate(installed, installed.copy(version = 4), 5)
        }
    }
    @Test fun checksStreamedHashAgainstKnownVector() {
        val hash = ApkUpdatePolicy.digest("abc".byteInputStream())
        ApkUpdatePolicy.validateHash(hash, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        assertEquals(32, hash.size)
    }
    @Test fun rejectsTamperedOrInvalidHash() {
        val hash = ApkUpdatePolicy.digest("tampered".byteInputStream())
        for (expected in listOf("0".repeat(64), "invalid")) {
            assertThrows(IllegalArgumentException::class.java) { ApkUpdatePolicy.validateHash(hash, expected) }
        }
    }
}
