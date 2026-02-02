package de.rub.nds.sshstatelearner.integration

import de.rub.nds.sshstatelearner.sul.NetworkSshServerSul
import de.rub.nds.sshstatelearner.extraction.SshSymbol
import de.rub.nds.sshstatelearner.sul.response.ResponseFingerprint
import org.junit.jupiter.api.AfterAll
import org.junit.jupiter.api.Assertions
import org.junit.jupiter.api.Assumptions
import org.junit.jupiter.api.BeforeAll
import org.junit.jupiter.api.Tag
import org.junit.jupiter.api.Test
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.Socket
import java.time.Duration
import java.time.Instant

@Tag("integration")
class OpensshIntegrationTest {
    companion object {
        // When Maven runs in the module directory, resolve compose file relative to module
        private const val COMPOSE_FILE = "../impl/openssh/docker-compose.yml"
        private const val HOST = "127.0.0.1"
        private const val PORT_START = 30020
        private const val PORT_END = 30035

        @BeforeAll
        @JvmStatic
        fun beforeAll() {
            // Try to run docker compose up -d. If docker isn't available, skip tests.
            val upCommand = arrayOf("docker", "compose", "-f", COMPOSE_FILE, "up", "--build", "-d")
            val fallback = arrayOf("docker-compose", "-f", COMPOSE_FILE, "up", "--build", "-d")
            var started = runCommand(upCommand)
            if (!started) started = runCommand(fallback)
            Assumptions.assumeTrue(started, "Docker is not available or compose failed; skipping integration tests")

            // wait a short while for the service to become reachable
            Thread.sleep(Duration.ofSeconds(5).toMillis())
        }

        @AfterAll
        @JvmStatic
        fun afterAll() {
            val downCommand = arrayOf("docker", "compose", "-f", COMPOSE_FILE, "down")
            val fallback = arrayOf("docker-compose", "-f", COMPOSE_FILE, "down")
            if (!runCommand(downCommand)) runCommand(fallback)
        }

        private fun runCommand(cmd: Array<String>): Boolean {
            return try {
                val pb = ProcessBuilder(*cmd)
                pb.redirectErrorStream(true)
                val p = pb.start()
                val reader = BufferedReader(InputStreamReader(p.inputStream))
                var line: String? = reader.readLine()
                while (line != null) {
                    line = reader.readLine()
                }
                val rc = p.waitFor()
                rc == 0
            } catch (e: Exception) {
                false
            }
        }
    }

    @Test
    fun testSendIgnoreAndExtInfo() {
        // Wait for the OpenSSH service to be reachable on any mapped host port in the compose range
        val port = waitForPortRange(HOST, PORT_START, PORT_END, 120)
        Assumptions.assumeTrue(port > 0, "OpenSSH not reachable on $HOST:$PORT_START-$PORT_END; skipping integration test")
        val sul = NetworkSshServerSul("openssh-test", HOST, port)
        try {
            sul.pre()

            // Send a large IGNORE payload
            val res1: ResponseFingerprint = sul.executeSymbol(SshSymbol.MSG_IGNORE_MAXIMUM)
            // We accept either some data or a close
            Assertions.assertNotNull(res1)

            // Send the strict-kex client extension info
            val res2: ResponseFingerprint = sul.executeSymbol(SshSymbol.MSG_EXT_INFO_STRICT_KEX_CLIENT)
            Assertions.assertNotNull(res2)
        } finally {
            sul.post()
            sul.close()
        }
    }

    private fun waitForPort(host: String, port: Int, timeoutSeconds: Long): Boolean {
        val deadline = Instant.now().plusSeconds(timeoutSeconds)
        while (Instant.now().isBefore(deadline)) {
            try {
                Socket(host, port).use { socket -> return true }
            } catch (_: Exception) {
                Thread.sleep(500)
            }
        }
        return false
    }

    private fun waitForPortRange(host: String, startPort: Int, endPort: Int, timeoutSeconds: Long): Int {
        val deadline = Instant.now().plusSeconds(timeoutSeconds)
        while (Instant.now().isBefore(deadline)) {
            for (p in startPort..endPort) {
                try {
                    Socket(host, p).use { socket -> return p }
                } catch (_: Exception) {
                    // try next port
                }
            }
            Thread.sleep(500)
        }
        return -1
    }
}
