import Toybox.Lang;
import Toybox.WatchUi;

//! The pages behind the glance: numbers first, then the summary.
class Pages extends WatchUi.ViewLoopFactory {

    function initialize() {
        ViewLoopFactory.initialize();
    }

    function getSize() as Number {
        return 2;
    }

    function getView(page as Number) as [ViewLoopFactory.Views] or [ViewLoopFactory.Views, ViewLoopFactory.Delegates] {
        // The docs call the delegate optional, but the app crashes on start without one.
        return [page == 0 ? new DetailView() : new SummaryView(), new WatchUi.BehaviorDelegate()];
    }
}
