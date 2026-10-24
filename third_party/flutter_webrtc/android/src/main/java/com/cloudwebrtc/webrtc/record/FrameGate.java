// AcroStella native recording fan-out. MIT; see package LICENSE.
package com.cloudwebrtc.webrtc.record;
import java.util.concurrent.atomic.AtomicBoolean;
/** One retained video frame at most; late frames are dropped, never queued. */
public final class FrameGate {
    private final AtomicBoolean held = new AtomicBoolean(false);
    private final AtomicBoolean closed = new AtomicBoolean(false);
    public boolean acquire() {
        if (closed.get() || !held.compareAndSet(false, true)) return false;
        if (closed.get()) { held.set(false); return false; }
        return true;
    }
    public void release() { held.set(false); }
    public void close() { closed.set(true); }
}
