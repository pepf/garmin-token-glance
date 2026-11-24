import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;

//! Shared by the glance and the detail page: reading the snapshot and drawing a bar.
(:glance)
module Usage {

    (:amoled) const ORANGE = 0xD97757;
    (:amoled) const RED = 0xFF4B3E;
    (:amoled) const TRACK = 0x3A3A3A;
    (:amoled) const GRADIENT_STEPS = 8;

    // 64-colour screens: exact palette colours, or orange and red round to the
    // same one. Gradients turn into bands there, so a flat fill.
    (:mip) const ORANGE = 0xFF5500;
    (:mip) const RED = 0xFF0000;
    (:mip) const TRACK = 0x555555;
    (:mip) const GRADIENT_STEPS = 1;

    const FIVE_HOURS = 5 * 3600;
    const SEVEN_DAYS = 7 * 86400;

    function snap() as Dictionary or Null {
        var s = Application.Storage.getValue("snap");
        return s instanceof Dictionary ? s : null;
    }

    function isConfigured() as Boolean {
        var host = Application.Properties.getValue("relayHost");
        var token = Application.Properties.getValue("token");
        return host instanceof String && token instanceof String && host.length() > 0 && token.length() > 0;
    }

    //! Seconds until the window resets; null if unknown or already passed.
    function secondsLeft(s as Dictionary, resetKey as String) as Number or Null {
        var r = s[resetKey];
        if (!(r instanceof Number)) {
            return null;
        }
        var left = r - Time.now().value();
        return left > 0 ? left : null;
    }

    //! Percent used right now. Once the reset time has passed the window is
    //! empty again, whatever the last snapshot said.
    function percent(s as Dictionary, key as String, resetKey as String) as Number or Null {
        var v = s[key];
        if (!(v instanceof Number)) {
            return null;
        }
        if (s[resetKey] instanceof Number && secondsLeft(s, resetKey) == null) {
            return 0;
        }
        return v < 0 ? 0 : (v > 100 ? 100 : v);
    }

    function duration(secs as Number) as String {
        if (secs >= 86400) {
            return (secs / 86400) + "d " + ((secs % 86400) / 3600) + "h";
        }
        if (secs >= 3600) {
            return (secs / 3600) + "h " + ((secs % 3600) / 60) + "m";
        }
        return (secs / 60) + "m";
    }

    //! Rounded bar with a pace tick at the elapsed fraction of the window.
    //! Fill past the tick means usage is running ahead of time.
    (:color)
    function drawBar(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number,
                     pct as Number or Null, left as Number or Null, window as Number) as Void {
        var r = h / 2;
        dc.setColor(TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, r);

        if (pct != null && pct > 0) {
            var fw = w * pct / 100;
            if (fw < h) {
                fw = h;
            }
            // Subtle gradient like native glance bars: stacked bands, each
            // shorter and a little lighter, so the fill brightens toward its tip.
            var base = pct >= 90 ? RED : ORANGE;
            var steps = GRADIENT_STEPS;
            for (var i = 0; i < steps; i++) {
                var t = (steps - 1 - i) * 4;
                var cr = (base >> 16) & 0xFF;
                var cg = (base >> 8) & 0xFF;
                var cb = base & 0xFF;
                cr += (255 - cr) * t / 100;
                cg += (255 - cg) * t / 100;
                cb += (255 - cb) * t / 100;
                dc.setColor((cr << 16) | (cg << 8) | cb, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(x, y, h + (fw - h) * (steps - i) / steps, h, r);
            }
        }

        if (left != null && left <= window) {
            var tx = x + w * (window - left) / window;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tx - 1, y - 3, 3, h + 6);
        }
    }

    //! 1-bit version: hairline track, solid fill, and a black gap around the
    //! tick so it stays visible on top of the fill.
    (:mono)
    function drawBar(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number,
                     pct as Number or Null, left as Number or Null, window as Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y + h / 2, w, 1);
        if (pct != null) {
            dc.fillRectangle(x, y, w * pct / 100, h);
        }

        if (left != null && left <= window) {
            var tx = x + (w - 2) * (window - left) / window;
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tx - 2, y - 2, 6, h + 4);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tx, y - 2, 2, h + 4);
        }
    }
}
