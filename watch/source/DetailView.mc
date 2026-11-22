import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Static page: both windows with bar, reset time and data age.
class DetailView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 12 / 100, Graphics.FONT_XTINY, "Claude", center);

        var s = Usage.snap();
        if (s == null) {
            dc.drawText(w / 2, h / 2, Graphics.FONT_TINY,
                Usage.isConfigured() ? "Waiting for data" : "Set up in Connect", center);
            return;
        }

        var left5 = Usage.secondsLeft(s, "r5");
        var reset5 = left5 != null ? "resets in " + Usage.duration(left5) : "";
        drawWindow(dc, h * 27 / 100, "5 hours", Usage.percent(s, "h5", "r5"), left5, Usage.FIVE_HOURS, reset5);

        var left7 = Usage.secondsLeft(s, "r7");
        var reset7 = "";
        var r7 = s["r7"];
        if (left7 != null && r7 instanceof Number) {
            var t = Gregorian.info(new Time.Moment(r7), Time.FORMAT_MEDIUM);
            reset7 = "resets " + t.day_of_week + " " + t.hour.format("%02d") + ":" + t.min.format("%02d");
        }
        drawWindow(dc, h * 55 / 100, "7 days", Usage.percent(s, "d7", "r7"), left7, Usage.SEVEN_DAYS, reset7);

        var ts = s["ts"];
        if (ts instanceof Number) {
            var age = Time.now().value() - ts;
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 86 / 100, Graphics.FONT_XTINY,
                "updated " + (age < 60 ? "just now" : Usage.duration(age) + " ago"), center);
        }
    }

    private function drawWindow(dc as Graphics.Dc, top as Number, label as String, pct as Number or Null,
                                left as Number or Null, window as Number, reset as String) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var x = w * 18 / 100;
        var bw = w * 64 / 100;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, top, Graphics.FONT_TINY, label, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x + bw, top, Graphics.FONT_TINY, pct != null ? pct + "%" : "--",
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        Usage.drawBar(dc, x, top + h * 7 / 100, bw, h * 3 / 100, pct, left, window);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, top + h * 16 / 100, Graphics.FONT_XTINY, reset,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
