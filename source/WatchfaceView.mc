import Toybox.Graphics;
import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;
import Toybox.WatchUi;

class WatchfaceView extends WatchUi.WatchFace {

    private const SCREEN_W = 176;
    private const SCREEN_H = 176;
    private const HEADER_TOP = 4;
    private const HEADER_BOTTOM = 17;
    private const UPPER_TOP = 17;
    private const UPPER_BOTTOM = 57;
    private const TIME_TOP = 57;
    private const TIME_BOTTOM = 87;
    private const DATE_TOP = 87;
    private const DATE_BOTTOM = 103;
    private const SUN_TOP = 103;
    private const SUN_BOTTOM = 117;
    private const STATS_TOP = 117;
    private const STATS_BOTTOM = 147;
    private const READINESS_TOP = 147;
    private const READINESS_BOTTOM = 172;

    private var _steps as Number? = null;
    private var _battery as Number? = null;
    private var _bodyBattery as Number? = null;
    private var _heartRate as Number? = null;
    private var _sunrise as Time.Moment? = null;
    private var _sunset as Time.Moment? = null;
    private var _lastDataMinute as Number = -1;
    private var _worldMap as BitmapResource? = null;

    function initialize() {
        WatchFace.initialize();
        _worldMap = WatchUi.loadResource($.Rez.Drawables.WorldMap) as BitmapResource;
    }

    function onUpdate(dc as Dc) as Void {
        if ((dc.getWidth() != SCREEN_W) || (dc.getHeight() != SCREEN_H)) {
            return;
        }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var clockTime = System.getClockTime();
        var hour = clockTime.hour;
        var minute = clockTime.min;
        var timeString = hour.format("%02d") + ":" + minute.format("%02d");

        if (_lastDataMinute != minute) {
            updateData();
            _lastDataMinute = minute;
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        drawHeader(dc);
        drawWorldMap(dc);
        drawAnalogClock(dc, 143, (UPPER_TOP + UPPER_BOTTOM) / 2, hour, minute);
        dc.drawText(SCREEN_W / 2, TIME_TOP + (TIME_BOTTOM - TIME_TOP - 23), Graphics.FONT_NUMBER_MEDIUM, timeString, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(SCREEN_W / 2, DATE_TOP + (DATE_BOTTOM - DATE_TOP - 15), Graphics.FONT_SYSTEM_XTINY, dateString(), Graphics.TEXT_JUSTIFY_CENTER);
        drawSunBar(dc);
        drawStats(dc);
        drawReadiness(dc);
    }

    private function updateData() as Void {
        _steps = null;
        _battery = null;
        _bodyBattery = null;
        _heartRate = null;
        _sunrise = null;
        _sunset = null;

        var activity = ActivityMonitor.getInfo();
        if ((activity has :steps) && (activity.steps != null)) {
            _steps = activity.steps;
        }

        var systemStats = System.getSystemStats();
        if (systemStats.battery != null) {
            _battery = (systemStats.battery + 0.5).toNumber();
        }

        if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
            var iterator = SensorHistory.getBodyBatteryHistory({
                :period => 1,
                :order => SensorHistory.ORDER_NEWEST_FIRST
            });
            var sample = iterator.next();
            if ((sample != null) && (sample.data != null)) {
                _bodyBattery = sample.data.toNumber();
            }
        }

        if ((Toybox has :SensorHistory) && (SensorHistory has :getHeartRateHistory)) {
            var heartRateIterator = SensorHistory.getHeartRateHistory({
                :period => 1,
                :order => SensorHistory.ORDER_NEWEST_FIRST
            });
            var heartRateSample = heartRateIterator.next();
            if ((heartRateSample != null) && (heartRateSample.data != null)) {
                _heartRate = heartRateSample.data.toNumber();
            }
        }

        if (Toybox has :Position) {
            var positionInfo = Position.getInfo();
            if ((positionInfo has :position) && (positionInfo.position != null)) {
                var today = Time.now();
                _sunrise = Weather.getSunrise(positionInfo.position, today);
                _sunset = Weather.getSunset(positionInfo.position, today);
            }
        }
    }

    private function dateString() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var weekdays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
        var months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
        return weekdays[info.day_of_week] + " " + info.day.format("%02d") + " " + months[(info.month as Number) - 1];
    }

    private function drawHeader(dc as Dc) as Void {
        dc.drawText(19, HEADER_TOP, Graphics.FONT_SYSTEM_XTINY, "IST +5:30", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(159, HEADER_TOP, Graphics.FONT_SYSTEM_XTINY, "GPS", Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawLine(22, HEADER_BOTTOM - 1, SCREEN_W - 22, HEADER_BOTTOM - 1);
    }

    private function drawWorldMap(dc as Dc) as Void {
        if (_worldMap != null) {
            dc.drawBitmap(18, UPPER_TOP + 4, _worldMap);
        }
        drawLocationMarker(dc);
    }

    private function drawLocationMarker(dc as Dc) as Void {
        dc.fillCircle(75, 37, 2);
    }

    private function drawAnalogClock(dc as Dc, centerX as Number, centerY as Number, hour as Number, minute as Number) as Void {
        dc.drawCircle(centerX, centerY, 18);
        dc.drawCircle(centerX, centerY, 15);
        for (var index = 0; index < 12; index++) {
            var angle = index * 30;
            var outerX = centerX + (Math.sin(angle) * 15).toNumber();
            var outerY = centerY - (Math.cos(angle) * 15).toNumber();
            var innerX = centerX + (Math.sin(angle) * 12).toNumber();
            var innerY = centerY - (Math.cos(angle) * 12).toNumber();
            dc.drawLine(innerX, innerY, outerX, outerY);
        }
        drawHand(dc, centerX, centerY, ((hour % 12) * 30) + (minute / 2), 9);
        drawHand(dc, centerX, centerY, minute * 6, 12);
        dc.fillCircle(centerX, centerY, 2);
    }

    private function drawHand(dc as Dc, centerX as Number, centerY as Number, angle as Number, length as Number) as Void {
        var handX = centerX + (Math.sin(angle) * length).toNumber();
        var handY = centerY - (Math.cos(angle) * length).toNumber();
        dc.drawLine(centerX, centerY, handX, handY);
    }

    private function drawSunBar(dc as Dc) as Void {
        var sunriseText = _sunrise == null ? "--:--" : formatSunTime(_sunrise);
        var sunsetText = _sunset == null ? "--:--" : formatSunTime(_sunset);
        var sunriseInfo = _sunrise == null ? null : Gregorian.info(_sunrise, Time.FORMAT_SHORT);
        var sunsetInfo = _sunset == null ? null : Gregorian.info(_sunset, Time.FORMAT_SHORT);
        var textY = SUN_TOP + 1;
        var barY = SUN_BOTTOM - (SUN_BOTTOM - SUN_TOP - 6);
        dc.drawText(18, textY, Graphics.FONT_XTINY, sunriseText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(SCREEN_W - 18, textY, Graphics.FONT_XTINY, sunsetText, Graphics.TEXT_JUSTIFY_RIGHT);

        var markerX = 88;
        if ((sunriseInfo != null) && (sunsetInfo != null)) {
            var sunriseMinutes = sunriseInfo.hour * 60 + sunriseInfo.min;
            var sunsetMinutes = sunsetInfo.hour * 60 + sunsetInfo.min;
            var currentTime = System.getClockTime();
            var currentMinutes = currentTime.hour * 60 + currentTime.min;
            if (sunsetMinutes > sunriseMinutes) {
                if (currentMinutes <= sunriseMinutes) {
                    markerX = 54;
                } else if (currentMinutes >= sunsetMinutes) {
                    markerX = 122;
                } else {
                    markerX = 54 + ((currentMinutes - sunriseMinutes) * 68 / (sunsetMinutes - sunriseMinutes));
                }
            }
        }
        dc.drawLine(54, barY + 2, 122, barY + 2);
        dc.drawLine(54, barY, 54, barY + 4);
        dc.drawLine(122, barY, 122, barY + 4);
        dc.fillCircle(markerX, barY + 2, 2);
    }

    private function formatSunTime(moment as Time.Moment) as String {
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        return info.hour.format("%02d") + ":" + info.min.format("%02d");
    }

    private function drawStats(dc as Dc) as Void {
        var labelY = STATS_TOP + 3;
        var valueY = STATS_BOTTOM - 15;
        var bodyValue = _bodyBattery == null ? "--" : compactNumber(_bodyBattery);
        var stepsValue = _steps == null ? "--" : compactNumber(_steps);
        var batteryValue = _battery == null ? "--" : compactNumber(_battery) + "%";

        dc.drawText(29, labelY, Graphics.FONT_SYSTEM_XTINY, "BODY", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(88, labelY, Graphics.FONT_SYSTEM_XTINY, "STEPS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(147, labelY, Graphics.FONT_SYSTEM_XTINY, "BAT", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(29, valueY, Graphics.FONT_SYSTEM_SMALL, bodyValue, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(88, valueY, Graphics.FONT_SYSTEM_SMALL, stepsValue, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(147, valueY, Graphics.FONT_SYSTEM_SMALL, batteryValue, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function compactNumber(value as Number?) as String {
        if (value == null) {
            return "--";
        }
        if (value > 9999) {
            return (value / 1000).format("%.1f") + "K";
        }
        return value.toString();
    }

    private function drawReadiness(dc as Dc) as Void {
        dc.drawLine(16, READINESS_TOP, SCREEN_W - 16, READINESS_TOP);
        var heartRateText = _heartRate == null ? "-- BPM" : _heartRate.toString() + " BPM";
        dc.drawText(SCREEN_W / 2, READINESS_BOTTOM - 24, Graphics.FONT_SYSTEM_XTINY, "HR", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(SCREEN_W / 2, READINESS_BOTTOM - 16, Graphics.FONT_SYSTEM_SMALL, heartRateText, Graphics.TEXT_JUSTIFY_CENTER);
    }
}