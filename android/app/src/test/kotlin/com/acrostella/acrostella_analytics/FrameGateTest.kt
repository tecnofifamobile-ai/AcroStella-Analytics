package com.acrostella.acrostella_analytics

import com.cloudwebrtc.webrtc.record.FrameGate
import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

class FrameGateTest {
    @Test fun onlyOneNativeFrameCanBeRetainedUnderConcurrentLoad() {
        val gate = FrameGate()
        val ready = CountDownLatch(12)
        val release = CountDownLatch(1)
        val accepted = AtomicInteger()
        val executor = Executors.newFixedThreadPool(12)
        repeat(12) { executor.submit {
            if (gate.acquire()) accepted.incrementAndGet()
            ready.countDown()
            release.await(2, TimeUnit.SECONDS)
        } }
        assertTrue(ready.await(2, TimeUnit.SECONDS))
        assertEquals(1, accepted.get())
        release.countDown()
        gate.release()
        assertTrue(gate.acquire())
        gate.close()
        gate.release()
        assertFalse(gate.acquire())
        executor.shutdownNow()
    }
}
