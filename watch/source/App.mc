import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

//! Entry point for all three binaries: foreground, glance and background.
(:background, :glance)
class App extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary or Null) as Void {
        // Re-registering restarts the interval, so only register once.
        if (Background.getTemporalEventRegisteredTime() == null) {
            Background.registerForTemporalEvent(new Time.Duration(5 * 60));
        }
    }

    //! GlanceView is (:glance), so absent from the background binary.
    (:typecheck(disableBackgroundCheck))
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new GlanceView()];
    }

    //! DetailView is foreground-only.
    (:typecheck([disableBackgroundCheck, disableGlanceCheck]))
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new DetailView()];
    }

    //! Fetch is (:background), so absent from the glance binary.
    (:typecheck(disableGlanceCheck))
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new Fetch()];
    }

    //! Receives the Background.exit() payload. Failed fetches exit with the
    //! response code, which is not stored: the last good snapshot stays.
    function onBackgroundData(data as Application.PersistableType) as Void {
        if (data instanceof Dictionary) {
            Application.Storage.setValue("snap", data as Dictionary<Application.Storage.KeyType, Application.Storage.ValueType>);
            WatchUi.requestUpdate();
        }
    }
}
