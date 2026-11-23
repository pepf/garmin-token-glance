import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Static page: both windows with bar, reset time and data age.
class DetailView extends WatchUi.View {

    // Positions in percent of the screen.
    (:color) private const MARGIN = 18;
    (:color) private const TITLE_X = 50;
    (:color) private const TITLE_Y = 12;
    (:color) private const TOP5 = 27;
    (:color) private const TOP7 = 55;
    (:color) private const BAR_Y = 7;
    (:color) private const AGE_Y = 86;
    (:color) private const AGE_LABEL = "updated ";
    (:color) private const AGE_COLOR = Graphics.COLOR_DK_GRAY;

    // The subscreen takes the top right, so the title and "5 hours" sit left of it.
    (:mono) private const MARGIN = 8;
    (:mono) private const TITLE_X = 32;
    (:mono) private const TITLE_Y = 17;
    (:mono) private const TOP5 = 35;
    (:mono) private const TOP7 = 61;
    (:mono) private const BAR_Y = 8;
    (:mono) private const AGE_Y = 89;
    (:mono) private const AGE_LABEL = "data ";
    (:mono) private const AGE_COLOR = Graphics.COLOR_WHITE;

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
        dc.drawText(w * TITLE_X / 100, h * TITLE_Y / 100, Graphics.FONT_XTINY, "Claude", center);

        var s = Usage.snap();
        if (s == null) {
            dc.drawText(w / 2, h / 2, Graphics.FONT_TINY,
                Usage.isConfigured() ? "Waiting for data" : "Set up in Connect", center);
            return;
        }

        var left5 = Usage.secondsLeft(s, "r5");
        var reset5 = left5 != null ? "resets in " + Usage.duration(left5) : "";
        drawWindow(dc, h * TOP5 / 100, "5 hours", Usage.percent(s, "h5", "r5"), left5, Usage.FIVE_HOURS, reset5);

        var left7 = Usage.secondsLeft(s, "r7");
        var reset7 = "";
        var r7 = s["r7"];
        if (left7 != null && r7 instanceof Number) {
            var t = Gregorian.info(new Time.Moment(r7), Time.FORMAT_MEDIUM);
            reset7 = "resets " + t.day_of_week + " " + t.hour.format("%02d") + ":" + t.min.format("%02d");
        }
        drawWindow(dc, h * TOP7 / 100, "7 days", Usage.percent(s, "d7", "r7"), left7, Usage.SEVEN_DAYS, reset7);

        var ts = s["ts"];
        if (ts instanceof Number) {
            var age = Time.now().value() - ts;
            dc.setColor(AGE_COLOR, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * AGE_Y / 100, Graphics.FONT_XTINY,
                AGE_LABEL + (age < 60 ? "just now" : Usage.duration(age) + " ago"), center);
        }
    }

    (:color)
    private function drawValue(dc as Graphics.Dc, right as Number, y as Number, window as Number, value as String) as Void {
        dc.drawText(right, y, Graphics.FONT_TINY, value, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! The 5-hour row ends under the subscreen, so its value goes inside it.
    (:mono)
    private function drawValue(dc as Graphics.Dc, right as Number, y as Number, window as Number, value as String) as Void {
        var sub = WatchUi.getSubscreen();
        if (window == Usage.FIVE_HOURS && sub != null) {
            dc.drawText((sub.x as Number) + sub.width / 2, (sub.y as Number) + sub.height / 2, Graphics.FONT_LARGE, value,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.drawText(right, y, Graphics.FONT_TINY, value, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function drawWindow(dc as Graphics.Dc, top as Number, label as String, pct as Number or Null,
                                left as Number or Null, window as Number, reset as String) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var x = w * MARGIN / 100;
        var bw = w * (100 - 2 * MARGIN) / 100;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, top, Graphics.FONT_TINY, label, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        drawValue(dc, x + bw, top, window, pct != null ? pct + "%" : "--");

        Usage.drawBar(dc, x, top + h * BAR_Y / 100, bw, h * 3 / 100, pct, left, window);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, top + h * 16 / 100, Graphics.FONT_XTINY, reset,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
