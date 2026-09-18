import Toybox.Graphics;
import Toybox.Lang;
import Toybox.ActivityMonitor;
import Toybox.Math;
import Toybox.Position;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;
import Toybox.WatchUi;

// Compact monochrome instrument panel for the 176 x 176 Instinct 2X.
class WatchfaceView extends WatchUi.WatchFace {
    private const SCREEN_W = 176;
    private const SCREEN_H = 176;
    private const DEG_TO_RAD = 0.0174532925;
    private var _steps = null;
    private var _battery = null;
    private var _bodyBattery = null;
    private var _sunrise as Time.Moment? = null;
    private var _sunset as Time.Moment? = null;
    private var _latitude = null;
    private var _longitude = null;
    private var _lastDataMinute = -1;
    private var _worldMap as BitmapResource? = null;

    function initialize() {
        WatchFace.initialize();
        _worldMap = WatchUi.loadResource($.Rez.Drawables.WorldMap) as BitmapResource;
    }

    function onUpdate(dc as Dc) as Void {
        if ((dc.getWidth() != SCREEN_W) || (dc.getHeight() != SCREEN_H)) { return; }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        var clock = System.getClockTime();
        if (_lastDataMinute != clock.min) { updateData(); _lastDataMinute = clock.min; }
        drawTop(dc, clock.hour, clock.min);
        drawTimeAndDate(dc, clock.hour, clock.min);
        drawSun(dc);
        drawStats(dc);
        drawLocationPanel(dc);
    }

    // Data gathering intentionally remains separate from the visual layout.
    private function updateData() as Void {
        _steps = null; _battery = null; _bodyBattery = null;
        _sunrise = null; _sunset = null; _latitude = null; _longitude = null;
        var activity = ActivityMonitor.getInfo();
        if ((activity has :steps) && (activity.steps != null)) { _steps = activity.steps; }
        var systemStats = System.getSystemStats();
        if (systemStats.battery != null) { _battery = (systemStats.battery + 0.5).toNumber(); }
        if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
            var iterator = SensorHistory.getBodyBatteryHistory({:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST});
            var sample = iterator.next();
            if ((sample != null) && (sample.data != null)) { _bodyBattery = sample.data.toNumber(); }
        }
        if (Toybox has :Position) {
            var positionInfo = Position.getInfo();
            if ((positionInfo has :position) && (positionInfo.position != null)) {
                var location = positionInfo.position;
                var degrees = location.toDegrees();
                if (degrees != null) { _latitude = degrees[0]; _longitude = degrees[1]; }
                _sunrise = Weather.getSunrise(location, Time.now());
                _sunset = Weather.getSunset(location, Time.now());
            }
        }
    }

    private function drawTop(dc as Dc, hour as Number, minute as Number) as Void {
        dc.drawText(20, 2, Graphics.FONT_SYSTEM_XTINY, "IST +5:30", Graphics.TEXT_JUSTIFY_LEFT);
        drawChamferedRect(dc, 9, 17, 92, 49, 4);
        if (_worldMap != null) { dc.drawBitmap(14, 22, _worldMap); }
        drawLocationMarker(dc);
        drawAnalog(dc, 143, 32, hour, minute);
    }

    private function drawLocationMarker(dc as Dc) as Void {
        var x = 53; var y = 34;
        if ((_latitude != null) && (_longitude != null)) {
            x = 17 + (((_longitude + 180) * 67) / 360).toNumber();
            y = 23 + (((90 - _latitude) * 20) / 180).toNumber();
            if (x < 17) { x = 17; } if (x > 84) { x = 84; }
            if (y < 23) { y = 23; } if (y > 43) { y = 43; }
        }
        dc.drawLine(x - 3, y, x + 3, y); dc.drawLine(x, y - 3, x, y + 3); dc.fillCircle(x, y, 1);
    }

    private function drawAnalog(dc as Dc, cx as Number, cy as Number, hour as Number, minute as Number) as Void {
        dc.drawCircle(cx, cy, 19); dc.drawCircle(cx, cy, 17);
        for (var i = 0; i < 60; i++) {
            var angle = i * 6 * DEG_TO_RAD;
            var outer = (i % 5 == 0) ? 15 : 14;
            var inner = (i % 5 == 0) ? 12 : 13;
            dc.drawLine(cx + (Math.sin(angle) * inner).toNumber(), cy - (Math.cos(angle) * inner).toNumber(), cx + (Math.sin(angle) * outer).toNumber(), cy - (Math.cos(angle) * outer).toNumber());
        }
        dc.drawText(cx, cy - 14, Graphics.FONT_SYSTEM_XTINY, "12", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx + 12, cy - 4, Graphics.FONT_SYSTEM_XTINY, "3", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, cy + 8, Graphics.FONT_SYSTEM_XTINY, "6", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx - 12, cy - 4, Graphics.FONT_SYSTEM_XTINY, "9", Graphics.TEXT_JUSTIFY_CENTER);
        drawHand(dc, cx, cy, ((hour % 12) * 30) + (minute / 2), 8);
        drawHand(dc, cx, cy, minute * 6, 11); dc.fillCircle(cx, cy, 2);
    }

    private function drawHand(dc as Dc, cx as Number, cy as Number, angle as Number, length as Number) as Void {
        var radians = angle * DEG_TO_RAD;
        dc.drawLine(cx, cy, cx + (Math.sin(radians) * length).toNumber(), cy - (Math.cos(radians) * length).toNumber());
    }

    private function drawTimeAndDate(dc as Dc, hour as Number, minute as Number) as Void {
        var time = hour.format("%02d") + ":" + minute.format("%02d");
        dc.drawText(61, 48, Graphics.FONT_NUMBER_MILD, time, Graphics.TEXT_JUSTIFY_CENTER);
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var weekdays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
        var months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
        drawChamferedRect(dc, 120, 64, 168, 80, 2);
        dc.drawText(144, 67, Graphics.FONT_SYSTEM_XTINY, weekdays[(info.day_of_week as Number) - 1] + " " + info.day.format("%02d"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(144, 75, Graphics.FONT_SYSTEM_XTINY, months[(info.month as Number) - 1], Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawSun(dc as Dc) as Void {
        var sunrise = _sunrise == null ? "--:--" : formatSunTime(_sunrise);
        var sunset = _sunset == null ? "--:--" : formatSunTime(_sunset);
        drawSunIcon(dc, 15, 91); drawSunIcon(dc, 161, 91);
        dc.drawText(25, 85, Graphics.FONT_SYSTEM_XTINY, sunrise, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(151, 85, Graphics.FONT_SYSTEM_XTINY, sunset, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawLine(50, 93, 126, 93);
        for (var i = 0; i <= 10; i++) { var x = 50 + ((76 * i) / 10); dc.drawLine(x, 91, x, 95); }
        dc.fillCircle(daylightMarker(), 93, 2);
    }

    private function daylightMarker() as Number {
        var left = 50; var right = 126;
        if ((_sunrise == null) || (_sunset == null)) { return 88; }
        var rise = Gregorian.info(_sunrise, Time.FORMAT_SHORT); var set = Gregorian.info(_sunset, Time.FORMAT_SHORT); var now = System.getClockTime();
        var riseMin = rise.hour * 60 + rise.min; var setMin = set.hour * 60 + set.min; var nowMin = now.hour * 60 + now.min;
        if (setMin <= riseMin) { return 88; } if (nowMin <= riseMin) { return left; } if (nowMin >= setMin) { return right; }
        return left + (((nowMin - riseMin) * (right - left)) / (setMin - riseMin));
    }

    private function drawSunIcon(dc as Dc, x as Number, y as Number) as Void {
        dc.drawLine(x - 5, y + 3, x + 5, y + 3); dc.drawLine(x - 3, y, x + 3, y); dc.drawLine(x, y - 4, x, y - 1);
        dc.drawLine(x - 4, y - 2, x - 2, y); dc.drawLine(x + 4, y - 2, x + 2, y);
    }

    private function formatSunTime(moment as Time.Moment) as String {
        var info = Gregorian.info(moment, Time.FORMAT_SHORT); return info.hour.format("%02d") + ":" + info.min.format("%02d");
    }

    private function drawStats(dc as Dc) as Void {
        drawChamferedRect(dc, 8, 102, 168, 141, 3); dc.drawLine(61, 102, 61, 141); dc.drawLine(115, 102, 115, 141);
        dc.drawText(34, 105, Graphics.FONT_SYSTEM_XTINY, "BODY", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(88, 105, Graphics.FONT_SYSTEM_XTINY, "STEPS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(141, 105, Graphics.FONT_SYSTEM_XTINY, "BATT", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(34, 119, Graphics.FONT_SYSTEM_SMALL, compactNumber(_bodyBattery), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(88, 119, Graphics.FONT_SYSTEM_SMALL, compactNumber(_steps), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(141, 119, Graphics.FONT_SYSTEM_SMALL, _battery == null ? "--" : compactNumber(_battery) + "%", Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawBodyIcon(dc as Dc, x as Number, y as Number) as Void {
        dc.drawCircle(x, y - 6, 2); dc.drawLine(x, y - 3, x, y + 5); dc.drawLine(x - 4, y, x, y + 2); dc.drawLine(x + 4, y, x, y + 2); dc.drawLine(x, y + 5, x - 3, y + 10); dc.drawLine(x, y + 5, x + 3, y + 10);
    }
    private function drawStepsIcon(dc as Dc, x as Number, y as Number) as Void {
        dc.fillCircle(x - 3, y + 3, 3); dc.fillCircle(x + 4, y - 3, 3); dc.drawLine(x - 4, y - 2, x - 2, y - 5); dc.drawLine(x + 3, y - 8, x + 5, y - 11);
    }
    private function drawBatteryIcon(dc as Dc, x as Number, y as Number) as Void {
        dc.drawRectangle(x, y, 11, 18); dc.drawLine(x + 3, y - 2, x + 8, y - 2); dc.drawLine(x + 3, y + 3, x + 3, y + 15);
    }

    // Training Status is deliberately replaced with position data already collected by this face.
    private function drawLocationPanel(dc as Dc) as Void {
        drawChamferedRect(dc, 18, 147, 158, 171, 5);
        dc.drawText(47, 150, Graphics.FONT_SYSTEM_XTINY, "GPS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(91, 156, Graphics.FONT_SYSTEM_SMALL, locationText(), Graphics.TEXT_JUSTIFY_CENTER); drawGpsIcon(dc, 140, 159);
    }
    private function locationText() as String {
        if ((_latitude == null) || (_longitude == null)) { return "SEARCH"; }
        return "LOCKED";
    }
    private function drawGpsIcon(dc as Dc, x as Number, y as Number) as Void {
        dc.drawCircle(x, y, 7); dc.drawCircle(x, y, 2); dc.drawLine(x - 10, y, x - 7, y); dc.drawLine(x + 7, y, x + 10, y); dc.drawLine(x, y - 10, x, y - 7); dc.drawLine(x, y + 7, x, y + 10);
    }

    private function drawChamferedRect(dc as Dc, l as Number, t as Number, r as Number, b as Number, c as Number) as Void {
        dc.drawLine(l + c, t, r - c, t); dc.drawLine(l + c, b, r - c, b); dc.drawLine(l, t + c, l, b - c); dc.drawLine(r, t + c, r, b - c);
        dc.drawLine(l, t + c, l + c, t); dc.drawLine(r - c, t, r, t + c); dc.drawLine(l, b - c, l + c, b); dc.drawLine(r, b - c, r - c, b);
    }
    private function compactNumber(value) as String {
        if (value == null) { return "--"; } if (value > 9999) { return (value / 1000).format("%.1f") + "K"; } return value.toString();
    }
}
