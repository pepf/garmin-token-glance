import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Second page: what the numbers mean, in words.
class SummaryView extends WatchUi.View {

    // Positions in percent of the screen.
    (:color) private const HEAD_X = 50;
    (:color) private const HEAD_Y = 21;
    (:color) private const MARGIN = 14;
    (:color) private const TOP = 31;
    (:color) private const BOTTOM = 83;

    // The headline sits left of the subscreen, the text below it.
    (:mono) private const HEAD_X = 32;
    (:mono) private const HEAD_Y = 22;
    (:mono) private const MARGIN = 5;
    (:mono) private const TOP = 36;
    (:mono) private const BOTTOM = 91;

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        var s = Usage.snap();
        var advice = s != null ? Coach.advice(s) : null;
        if (s == null || advice == null) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2, Graphics.FONT_TINY,
                Usage.isConfigured() ? "Waiting for data" : "Set up in Connect", center);
            return;
        }

        setHeadColor(dc, s);
        dc.drawText(w * HEAD_X / 100, h * HEAD_Y / 100, Graphics.FONT_TINY, advice[0], center);

        var top = h * TOP / 100;
        var bw = w * (100 - 2 * MARGIN) / 100;
        var bh = h * (BOTTOM - TOP) / 100;
        var fonts = [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY];
        var i = 0;
        var text = Graphics.fitTextToArea(advice[1], fonts[0], bw, bh, false);
        while (text == null && i < fonts.size() - 1) {
            i++;
            text = Graphics.fitTextToArea(advice[1], fonts[i], bw, bh, i == fonts.size() - 1);
        }
        if (text != null) {
            var y = top + (bh - dc.getTextDimensions(text, fonts[i])[1]) / 2;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y, fonts[i], text, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    (:color)
    private function setHeadColor(dc as Graphics.Dc, s as Dictionary) as Void {
        var h5 = Usage.percent(s, "h5", "r5");
        var d7 = Usage.percent(s, "d7", "r7");
        var red = (h5 != null && h5 >= 90) || (d7 != null && d7 >= 90);
        dc.setColor(red ? Usage.RED : Usage.ORANGE, Graphics.COLOR_TRANSPARENT);
    }

    (:mono)
    private function setHeadColor(dc as Graphics.Dc, s as Dictionary) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    }
}
