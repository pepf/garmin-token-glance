import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

//! One web request, then exactly one Background.exit() on every path.
(:background)
class Fetch extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var host = Application.Properties.getValue("relayHost");
        var token = Application.Properties.getValue("token");
        if (!(host instanceof String) || !(token instanceof String) || host.length() == 0 || token.length() == 0) {
            Background.exit(null);
            return;
        }

        // Token in the header, never the URL: the relay's access logs record URLs.
        Communications.makeWebRequest("https://" + host + "/usage", null, {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :headers => { "Authorization" => "Bearer " + token }
        }, method(:onResponse));
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        System.println("fetch " + code);
        if (code == 200 && data instanceof Dictionary) {
            Background.exit(data as Application.PersistableType);
        } else {
            Background.exit(code);
        }
    }
}
