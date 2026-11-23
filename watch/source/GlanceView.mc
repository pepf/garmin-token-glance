import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Title row, 5-hour value row, then a 5-hour and a thinner 7-day bar.
//! Drawn from the stored snapshot only: no network, timers or animation.
(:glance, :color)
class GlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var left = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        var right = Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER;
        var titleY = h * 16 / 100;
        var valueY = h * 50 / 100;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, titleY, Graphics.FONT_GLANCE, "Claude", left);

        var s = Usage.snap();
        if (s == null) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(0, valueY, Graphics.FONT_GLANCE,
                Usage.isConfigured() ? "Waiting for data" : "Set up in Connect", left);
            return;
        }

        var h5 = Usage.percent(s, "h5", "r5");
        var d7 = Usage.percent(s, "d7", "r7");
        var left5 = Usage.secondsLeft(s, "r5");
        var left7 = Usage.secondsLeft(s, "r7");

        if (d7 != null) {
            dc.setColor(d7 >= 90 ? Usage.RED : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w, titleY, Graphics.FONT_GLANCE, "7d " + d7 + "%", right);
        }

        // The number font may be digits-only, so the % sign uses the text font.
        var num = h5 != null ? h5.toString() : "--";
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, valueY, Graphics.FONT_GLANCE_NUMBER, num, left);
        dc.drawText(dc.getTextWidthInPixels(num, Graphics.FONT_GLANCE_NUMBER) + 2, valueY,
            Graphics.FONT_GLANCE, "%", left);

        if (left5 != null) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w, valueY, Graphics.FONT_GLANCE, Usage.duration(left5), right);
        }

        var bar5 = h * 8 / 100;
        var bar7 = h * 5 / 100;
        Usage.drawBar(dc, 0, h * 70 / 100, w, bar5, h5, left5, Usage.FIVE_HOURS);
        Usage.drawBar(dc, 0, h * 84 / 100, w, bar7, d7, left7, Usage.SEVEN_DAYS);
    }
}
