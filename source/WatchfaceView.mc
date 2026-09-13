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

class WatchfaceView extends WatchUi.WatchFace {

    private const SCREEN_W = 176;
    private const SCREEN_H = 176;

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

        _worldMap = WatchUi.loadResource(
            $.Rez.Drawables.WorldMap
        ) as BitmapResource;
    }


    function onUpdate(dc as Dc) as Void {

        if ((dc.getWidth() != SCREEN_W) ||
            (dc.getHeight() != SCREEN_H)) {
            return;
        }

        dc.setColor(
            Graphics.COLOR_BLACK,
            Graphics.COLOR_BLACK
        );
        dc.clear();

        var clockTime = System.getClockTime();

        var hour = clockTime.hour;
        var minute = clockTime.min;

        if (_lastDataMinute != minute) {
            updateData();
            _lastDataMinute = minute;
        }

        dc.setColor(
            Graphics.COLOR_WHITE,
            Graphics.COLOR_BLACK
        );

        drawTop(dc, hour, minute);
        drawTimeAndDate(dc);
        drawSun(dc);
        drawStats(dc);
        drawBottomPanel(dc);
    }


    // ============================================================
    // DATA
    // ============================================================

    private function updateData() as Void {

        _steps = null;
        _battery = null;
        _bodyBattery = null;

        _sunrise = null;
        _sunset = null;

        _latitude = null;
        _longitude = null;


        var activity = ActivityMonitor.getInfo();

        if ((activity has :steps) &&
            (activity.steps != null)) {
            _steps = activity.steps;
        }


        var systemStats = System.getSystemStats();

        if (systemStats.battery != null) {
            _battery =
                (systemStats.battery + 0.5).toNumber();
        }


        if ((Toybox has :SensorHistory) &&
            (SensorHistory has :getBodyBatteryHistory)) {

            var iterator =
                SensorHistory.getBodyBatteryHistory({
                    :period => 1,
                    :order => SensorHistory.ORDER_NEWEST_FIRST
                });

            var sample = iterator.next();

            if ((sample != null) &&
                (sample.data != null)) {
                _bodyBattery =
                    sample.data.toNumber();
            }
        }


        if (Toybox has :Position) {

            var positionInfo = Position.getInfo();

            if ((positionInfo has :position) &&
                (positionInfo.position != null)) {

                var location = positionInfo.position;

                var degrees = location.toDegrees();

                if (degrees != null) {
                    _latitude = degrees[0];
                    _longitude = degrees[1];
                }

                var today = Time.now();

                _sunrise =
                    Weather.getSunrise(
                        location,
                        today
                    );

                _sunset =
                    Weather.getSunset(
                        location,
                        today
                    );
            }
        }
    }


    // ============================================================
    // TOP
    // ============================================================

    private function drawTop(
        dc as Dc,
        hour as Number,
        minute as Number
    ) as Void {

        dc.drawText(
            12,
            1,
            Graphics.FONT_SYSTEM_XTINY,
            "IST +5:30",
            Graphics.TEXT_JUSTIFY_LEFT
        );


        drawMapFrame(dc);


        if (_worldMap != null) {
            dc.drawBitmap(
                10,
                6,
                _worldMap
            );
        }


        drawLocationMarker(dc);


        drawAnalog(
            dc,
            154,
            18,
            hour,
            minute
        );
    }


    private function drawMapFrame(
        dc as Dc
    ) as Void {

        var l = 8;
        var r = 90;
        var t = 5;
        var b = 37;


        dc.drawLine(l + 5, t, r - 5, t);
        dc.drawLine(l + 5, b, r - 5, b);

        dc.drawLine(l, t + 5, l, b - 5);
        dc.drawLine(r, t + 5, r, b - 5);

        dc.drawLine(l, t + 5, l + 5, t);
        dc.drawLine(r - 5, t, r, t + 5);

        dc.drawLine(l, b - 5, l + 5, b);
        dc.drawLine(r - 5, b, r, b - 5);
    }


    private function drawLocationMarker(
        dc as Dc
    ) as Void {

        var x = 51;
        var y = 25;


        if ((_latitude != null) &&
            (_longitude != null)) {

            x =
                14 +
                (((_longitude + 180) * 72) / 360)
                    .toNumber();

            y =
                11 +
                (((90 - _latitude) * 30) / 150)
                    .toNumber();


            if (x < 15) {
                x = 15;
            }

            if (x > 85) {
                x = 85;
            }

            if (y < 12) {
                y = 12;
            }

            if (y > 40) {
                y = 40;
            }
        }


        dc.drawLine(
            x - 3,
            y,
            x + 3,
            y
        );

        dc.drawLine(
            x,
            y - 3,
            x,
            y + 3
        );

        dc.fillCircle(
            x,
            y,
            1
        );
    }




    // ============================================================
    // ANALOG
    // ============================================================

    private function drawAnalog(
        dc as Dc,
        cx as Number,
        cy as Number,
        hour as Number,
        minute as Number
    ) as Void {

        var r = 14;


        dc.drawCircle(
            cx,
            cy,
            r
        );

        dc.drawCircle(
            cx,
            cy,
            r - 2
        );


        for (var i = 0; i < 12; i++) {

            var angle = i * 30;

            var ox =
                cx +
                (Math.sin(angle) * 8).toNumber();

            var oy =
                cy -
                (Math.cos(angle) * 8).toNumber();

            var ix =
                cx +
                (Math.sin(angle) * 8).toNumber();

            var iy =
                cy -
                (Math.cos(angle) * 8).toNumber();

            dc.drawLine(
                ix,
                iy,
                ox,
                oy
            );
        }


        dc.drawText(
            cx,
            cy - 11,
            Graphics.FONT_SYSTEM_XTINY,
            "12",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.drawText(
            cx + 9,
            cy - 4,
            Graphics.FONT_SYSTEM_XTINY,
            "3",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.drawText(
            cx,
            cy + 7,
            Graphics.FONT_SYSTEM_XTINY,
            "6",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.drawText(
            cx - 9,
            cy - 4,
            Graphics.FONT_SYSTEM_XTINY,
            "9",
            Graphics.TEXT_JUSTIFY_CENTER
        );


        drawHand(
            dc,
            cx,
            cy,
            ((hour % 12) * 30) +
            (minute / 2),
            6
        );

        drawHand(
            dc,
            cx,
            cy,
            minute * 6,
            9
        );

        dc.fillCircle(
            cx,
            cy,
            2
        );
    }


    private function drawHand(
        dc as Dc,
        cx as Number,
        cy as Number,
        angle as Number,
        length as Number
    ) as Void {

        var x =
            cx +
            (Math.sin(angle) * length).toNumber();

        var y =
            cy -
            (Math.cos(angle) * length).toNumber();

        dc.drawLine(
            cx,
            cy,
            x,
            y
        );
    }


    // ============================================================
    // TIME + DATE
    // ============================================================

    private function drawTimeAndDate(
        dc as Dc
    ) as Void {

        var clock = System.getClockTime();

        var time =
            clock.hour.format("%02d") +
            ":" +
            clock.min.format("%02d");


        dc.drawText(
            63,
            44,
            Graphics.FONT_LARGE,
            time,
            Graphics.TEXT_JUSTIFY_CENTER
        );


        var info =
            Gregorian.info(
                Time.now(),
                Time.FORMAT_SHORT
            );


        var weekdays = [
            "SUN",
            "MON",
            "TUE",
            "WED",
            "THU",
            "FRI",
            "SAT"
        ];


        var months = [
            "JAN",
            "FEB",
            "MAR",
            "APR",
            "MAY",
            "JUN",
            "JUL",
            "AUG",
            "SEP",
            "OCT",
            "NOV",
            "DEC"
        ];


        // Compact date field beside the main time.

        dc.drawText(
            139,
            47,
            Graphics.FONT_SYSTEM_XTINY,
            weekdays[info.day_of_week] +
            " " +
            info.day.format("%02d"),
            Graphics.TEXT_JUSTIFY_CENTER
        );


        dc.drawText(
            139,
            58,
            Graphics.FONT_SYSTEM_XTINY,
            months[(info.month as Number) - 1] +
            " " +
            (info.year % 100).toString(),
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }


    // ============================================================
    // SUN
    // ============================================================

    private function drawSun(
        dc as Dc
    ) as Void {

        var sunrise =
            _sunrise == null
            ? "--:--"
            : formatSunTime(_sunrise);

        var sunset =
            _sunset == null
            ? "--:--"
            : formatSunTime(_sunset);


        drawSunIcon(dc, 16, 82);
        drawSunIcon(dc, 160, 82);


        dc.drawText(
            25,
            77,
            Graphics.FONT_SYSTEM_XTINY,
            sunrise,
            Graphics.TEXT_JUSTIFY_LEFT
        );

        dc.drawText(
            151,
            77,
            Graphics.FONT_SYSTEM_XTINY,
            sunset,
            Graphics.TEXT_JUSTIFY_RIGHT
        );


        var l = 51;
        var r = 125;
        var y = 85;


        dc.drawLine(
            l,
            y,
            r,
            y
        );


        for (var i = 0; i <= 10; i++) {

            var x =
                l +
                ((r - l) * i / 10);

            dc.drawLine(
                x,
                y - 2,
                x,
                y + 2
            );
        }


        var marker = 88;


        var rise =
            _sunrise == null
            ? null
            : Gregorian.info(
                _sunrise,
                Time.FORMAT_SHORT
            );

        var set =
            _sunset == null
            ? null
            : Gregorian.info(
                _sunset,
                Time.FORMAT_SHORT
            );


        if ((rise != null) &&
            (set != null)) {

            var riseMin =
                rise.hour * 60 +
                rise.min;

            var setMin =
                set.hour * 60 +
                set.min;

            var now =
                System.getClockTime();

            var nowMin =
                now.hour * 60 +
                now.min;


            if (setMin > riseMin) {

                if (nowMin <= riseMin) {

                    marker = l;

                } else if (nowMin >= setMin) {

                    marker = r;

                } else {

                    marker =
                        l +
                        (
                            (nowMin - riseMin) *
                            (r - l) /
                            (setMin - riseMin)
                        );
                }
            }
        }


        dc.fillCircle(
            marker,
            y,
            2
        );
    }


    private function drawSunIcon(
        dc as Dc,
        x as Number,
        y as Number
    ) as Void {

        dc.drawLine(
            x - 5,
            y + 3,
            x + 5,
            y + 3
        );

        dc.drawLine(
            x - 3,
            y,
            x + 3,
            y
        );

        dc.drawLine(
            x,
            y - 4,
            x,
            y - 1
        );

        dc.drawLine(
            x - 4,
            y - 2,
            x - 2,
            y
        );

        dc.drawLine(
            x + 4,
            y - 2,
            x + 2,
            y
        );
    }


    private function formatSunTime(
        moment as Time.Moment
    ) as String {

        var info =
            Gregorian.info(
                moment,
                Time.FORMAT_SHORT
            );

        return info.hour.format("%02d") +
            ":" +
            info.min.format("%02d");
    }


    // ============================================================
    // STATS
    // ============================================================

    private function drawStats(
        dc as Dc
    ) as Void {

        var l = 8;
        var r = 168;
        var t = 98;
        var b = 137;


        dc.drawLine(l, t, r, t);
        dc.drawLine(l, b, r, b);


        dc.drawLine(
            61,
            t,
            61,
            b
        );

        dc.drawLine(
            115,
            t,
            115,
            b
        );


        dc.drawLine(
            l,
            t,
            l + 4,
            t + 4
        );

        dc.drawLine(
            r,
            t,
            r - 4,
            t + 4
        );


        dc.drawText(
            34,
            101,
            Graphics.FONT_SYSTEM_XTINY,
            "BODY",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.drawText(
            88,
            101,
            Graphics.FONT_SYSTEM_XTINY,
            "STEPS",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.drawText(
            141,
            101,
            Graphics.FONT_SYSTEM_XTINY,
            "BAT",
            Graphics.TEXT_JUSTIFY_CENTER
        );


        var body =
            _bodyBattery == null
            ? "--"
            : compactNumber(_bodyBattery);

        var steps =
            _steps == null
            ? "--"
            : compactNumber(_steps);

        var battery =
            _battery == null
            ? "--"
            : compactNumber(_battery) + "%";


        dc.drawText(
            34,
            114,
            Graphics.FONT_SYSTEM_SMALL,
            body,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.drawText(
            88,
            114,
            Graphics.FONT_SYSTEM_SMALL,
            steps,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.drawText(
            141,
            114,
            Graphics.FONT_SYSTEM_SMALL,
            battery,
            Graphics.TEXT_JUSTIFY_CENTER
        );


    }


    // ============================================================
    // BOTTOM PANEL
    // ============================================================

    private function drawBottomPanel(
        dc as Dc
    ) as Void {

        var l = 18;
        var r = 158;
        var t = 145;
        var b = 173;


        // Main chamfered instrument panel.

        dc.drawLine(
            l + 5,
            t,
            r - 5,
            t
        );

        dc.drawLine(
            l,
            t + 5,
            l,
            b - 5
        );

        dc.drawLine(
            r,
            t + 5,
            r,
            b - 5
        );

        dc.drawLine(
            l + 5,
            b,
            r - 5,
            b
        );


        // Chamfered corners.

        dc.drawLine(
            l,
            t + 5,
            l + 5,
            t
        );

        dc.drawLine(
            r - 5,
            t,
            r,
            t + 5
        );

        dc.drawLine(
            l,
            b - 5,
            l + 5,
            b
        );

        dc.drawLine(
            r,
            b - 5,
            r - 5,
            b
        );
    }

    // ============================================================
    // HELPERS
    // ============================================================

    private function compactNumber(
        value
    ) as String {

        if (value == null) {
            return "--";
        }

        if (value > 9999) {
            return (value / 1000).format("%.1f") + "K";
        }

        return value.toString();
    }
}
