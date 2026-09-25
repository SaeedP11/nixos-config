pragma Singleton

// Solar Hijri (Jalali) dates for the Persian calendar chip, popout and
// desktop card. Qt has a Jalali QCalendar, but QML's Date formatting always
// uses the Gregorian one, so the conversion is done here: the 33-year
// arithmetic form, exact for every year this machine will see.
import QtQuick
import Quickshell

Singleton {
    readonly property var months: ["فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور", "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند"]
    // Indexed by Date.getDay(), Sunday first.
    readonly property var weekdays: ["یکشنبه", "دوشنبه", "سه‌شنبه", "چهارشنبه", "پنجشنبه", "جمعه", "شنبه"]
    // Column headers, Saturday first as a Persian week starts.
    readonly property var weekdaysShort: ["ش", "ی", "د", "س", "چ", "پ", "ج"]

    // Persian digits.
    function fa(n) {
        return String(n).replace(/\d/g, d => "۰۱۲۳۴۵۶۷۸۹"[d]);
    }

    // Gregorian Date -> {y, m, d}, m 1-based.
    function fromDate(date) {
        const gy = date.getFullYear(), gm = date.getMonth() + 1, gd = date.getDate();
        const gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
        const gy2 = gm > 2 ? gy + 1 : gy;
        let days = 355666 + 365 * gy + Math.floor((gy2 + 3) / 4) - Math.floor((gy2 + 99) / 100) + Math.floor((gy2 + 399) / 400) + gd + gdm[gm - 1];
        let y = -1595 + 33 * Math.floor(days / 12053);
        days %= 12053;
        y += 4 * Math.floor(days / 1461);
        days %= 1461;
        if (days > 365) {
            y += Math.floor((days - 1) / 365);
            days = (days - 1) % 365;
        }
        const m = days < 186 ? 1 + Math.floor(days / 31) : 7 + Math.floor((days - 186) / 30);
        const d = 1 + (days < 186 ? days % 31 : (days - 186) % 30);
        return { y, m, d };
    }

    // Jalali y/m/d -> local Date at noon, so DST never shifts it a day.
    // m may run past 12 or below 1; it carries into the year.
    function toDate(y, m, d) {
        y += Math.floor((m - 1) / 12);
        m = ((m - 1) % 12 + 12) % 12 + 1;
        const jy = y + 1595;
        let days = -355668 + 365 * jy + Math.floor(jy / 33) * 8 + Math.floor((jy % 33 + 3) / 4) + d + (m < 7 ? (m - 1) * 31 : (m - 7) * 30 + 186);
        let gy = 400 * Math.floor(days / 146097);
        days %= 146097;
        if (days > 36524) {
            gy += 100 * Math.floor(--days / 36524);
            days %= 36524;
            if (days >= 365)
                days++;
        }
        gy += 4 * Math.floor(days / 1461);
        days %= 1461;
        if (days > 365) {
            gy += Math.floor((days - 1) / 365);
            days = (days - 1) % 365;
        }
        return new Date(gy, 0, days + 1, 12);
    }

    function monthLength(y, m) {
        return Math.round((toDate(y, m + 1, 1) - toDate(y, m, 1)) / 86400000);
    }

    // "۳ مهر ۱۴۰۵"
    function format(date) {
        const j = fromDate(date);
        return fa(j.d) + " " + months[j.m - 1] + " " + fa(j.y);
    }
    // "پنجشنبه ۳ مهر ۱۴۰۵"
    function formatLong(date) {
        return weekdays[date.getDay()] + " " + format(date);
    }
}
