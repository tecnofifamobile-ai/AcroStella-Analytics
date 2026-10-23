package com.acrostella.acrostella_analytics

import java.io.InputStream
import java.security.MessageDigest

data class ApkIdentity(val packageName: String, val version: Long, val signers: Set<String>)

/** Pure policy shared by archive inspection and installation. Android performs
 * its own final cryptographic APK validation and asks for user confirmation. */
object ApkUpdatePolicy {
    fun validate(installed: ApkIdentity, archive: ApkIdentity, expectedVersion: Long) {
        require(archive.packageName == installed.packageName) { "Wrong package" }
        require(archive.version == expectedVersion && archive.version > installed.version) { "Wrong version" }
        require(archive.signers.isNotEmpty() && archive.signers == installed.signers) { "Wrong signing key" }
    }

    fun digest(input: InputStream): ByteArray {
        val hash = MessageDigest.getInstance("SHA-256")
        val buffer = ByteArray(64 * 1024)
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            if (count > 0) hash.update(buffer, 0, count)
        }
        return hash.digest()
    }

    fun validateHash(actual: ByteArray, expected: String) {
        require(expected.matches(Regex("[a-f0-9]{64}"))) { "Invalid digest" }
        val bytes = expected.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
        require(MessageDigest.isEqual(actual, bytes)) { "Wrong digest" }
    }
}
