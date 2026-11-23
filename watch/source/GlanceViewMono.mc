import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Instinct Solar glance. The subscreen covers the right of the glance, so
//! everything stays in the left column, each bar under its own value.
(:glance, :mono)
class GlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var bw = dc.getWidth() * 56 / 100;
        var h = dc.getHeight();
        var left = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        // Indented: the screen's bevelled corner cuts into this row.
        dc.drawText(h / 10, h * 11 / 100, Graphics.FONT_XTINY, "Claude", left);

        var s = Usage.snap();
        if (s == null) {
            // Two short lines: one would run under the subscreen.
            var configured = Usage.isConfigured();
            dc.drawText(0, h * 40 / 100, Graphics.FONT_XTINY, configured ? "Waiting" : "Set up in", left);
            dc.drawText(0, h * 66 / 100, Graphics.FONT_XTINY, configured ? "for data" : "Connect", left);
            return;
        }

        var h5 = Usage.percent(s, "h5", "r5");
        var d7 = Usage.percent(s, "d7", "r7");
        var left5 = Usage.secondsLeft(s, "r5");
        var left7 = Usage.secondsLeft(s, "r7");

        dc.drawText(0, h * 36 / 100, Graphics.FONT_XTINY,
            (h5 != null ? h5 + "%" : "--") + (left5 != null ? " " + Usage.duration(left5) : ""), left);
        Usage.drawBar(dc, 0, h * 54 / 100, bw, h * 7 / 100, h5, left5, Usage.FIVE_HOURS);

        dc.drawText(0, h * 75 / 100, Graphics.FONT_XTINY, "7d " + (d7 != null ? d7 + "%" : "--"), left);
        Usage.drawBar(dc, 0, h * 90 / 100, bw, h * 7 / 100, d7, left7, Usage.SEVEN_DAYS);
    }
}
