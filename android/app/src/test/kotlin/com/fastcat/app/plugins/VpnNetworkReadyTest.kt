package com.fastcat.app.plugins

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.yield
import org.junit.Assert.*
import org.junit.Test

class VpnNetworkReadyTest {
    @Test fun readyCompletesStartup() = runBlocking {
        val ready = CompletableDeferred<Unit>()
        ready.complete(Unit)
        awaitVpnNetworkReady(ready, 100)
    }

    @Test fun registrationTimeoutIsFailureRatherThanCancellation() = runBlocking {
        val signal = CompletableDeferred<Unit>()
        val error = runCatching { awaitVpnNetworkReady(signal, 10) }.exceptionOrNull()
        assertTrue(error is IllegalStateException)
        assertFalse(error is CancellationException)
        assertFalse(signal.isCancelled)
    }

    @Test fun explicitStopRemainsCancellation() = runBlocking {
        val signal = CompletableDeferred<Unit>()
        val finished = CompletableDeferred<Throwable>()
        val job = launch {
            try { awaitVpnNetworkReady(signal, 60_000) }
            catch (error: Throwable) { finished.complete(error); throw error }
        }
        yield()
        job.cancelAndJoin()
        assertTrue(finished.await() is CancellationException)
        assertFalse(signal.isCancelled)
    }
}
