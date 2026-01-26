package de.rub.nds.sshstatelearner.extraction

import de.rub.nds.sshattacker.core.protocol.transport.message.ExtensionInfoMessage
import de.rub.nds.sshattacker.core.protocol.transport.message.IgnoreMessage
import de.rub.nds.sshattacker.core.protocol.transport.message.KeyExchangeInitMessage
import de.rub.nds.sshattacker.core.protocol.transport.message.NewKeysMessage
import de.rub.nds.sshattacker.core.protocol.transport.message.extension.UnknownExtension
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

internal class SshSymbolConstructorTest {

    @Test
    fun `ext info strict kex client constructs extension`() {
        val msg = SshSymbol.MSG_EXT_INFO_STRICT_KEX_CLIENT.messageConstructor(null)
        assertTrue(msg is ExtensionInfoMessage)
        val extMsg = msg as ExtensionInfoMessage
        assertEquals(1, extMsg.getExtensions().size)
        val ext = extMsg.getExtensions()[0] as UnknownExtension
        assertEquals("kex-strict-c-v00@openssh.com", ext.getName().getValue())
    }

    @Test
    fun `ext info strict kex server constructs extension`() {
        val msg = SshSymbol.MSG_EXT_INFO_STRICT_KEX_SERVER.messageConstructor(null)
        assertTrue(msg is ExtensionInfoMessage)
        val extMsg = msg as ExtensionInfoMessage
        assertEquals(1, extMsg.getExtensions().size)
        val ext = extMsg.getExtensions()[0] as UnknownExtension
        assertEquals("kex-strict-s-v00@openssh.com", ext.getName().getValue())
    }

    @Test
    fun `ignore maximum has large payload`() {
        val msg = SshSymbol.MSG_IGNORE_MAXIMUM.messageConstructor(null)
        assertTrue(msg is IgnoreMessage)
        val ignore = msg as IgnoreMessage
        val data = ignore.getData()
        assertNotNull(data)
        assertTrue(data.getValue().size >= 32768)
    }

    @Test
    fun `kexinit and newkeys variants construct expected types`() {
        val kex = SshSymbol.MSG_KEXINIT_STRICT_KEX_CLIENT.messageConstructor(null)
        assertTrue(kex is KeyExchangeInitMessage)

        val newkeys = SshSymbol.MSG_PREMATURE_NEWKEYS.messageConstructor(null)
        assertTrue(newkeys is NewKeysMessage)
    }
}
