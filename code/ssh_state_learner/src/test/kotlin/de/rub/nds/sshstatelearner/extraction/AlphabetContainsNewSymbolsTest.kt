package de.rub.nds.sshstatelearner.extraction

import de.rub.nds.sshattacker.core.constants.KeyExchangeAlgorithm
import de.rub.nds.sshstatelearner.constants.ProtocolStage
import de.rub.nds.sshstatelearner.constants.SulType
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class AlphabetContainsNewSymbolsTest {

    @Test
    fun `constructed alphabet includes strict kex and ignore symbols`() {
        val alphabet = AlphabetFactory.construct(
            SulType.SERVER,
            ProtocolStage.TRANSPORT,
            KeyExchangeAlgorithm.ECDH_SHA2_NISTP256
        )

        val found = (0 until alphabet.size).map { alphabet.getSymbol(it) }.toSet()

        assertTrue(found.contains(SshSymbol.MSG_EXT_INFO_STRICT_KEX_CLIENT), "EXT_INFO_STRICT_KEX_CLIENT missing")
        assertTrue(found.contains(SshSymbol.MSG_EXT_INFO_STRICT_KEX_SERVER), "EXT_INFO_STRICT_KEX_SERVER missing")
        assertTrue(found.contains(SshSymbol.MSG_IGNORE_MAXIMUM), "IGNORE_MAXIMUM missing")
        assertTrue(found.contains(SshSymbol.MSG_KEXINIT_STRICT_KEX_CLIENT), "KEXINIT_STRICT_KEX_CLIENT missing")
        assertTrue(found.contains(SshSymbol.MSG_PREMATURE_NEWKEYS), "PREMATURE_NEWKEYS missing")
    }
}
