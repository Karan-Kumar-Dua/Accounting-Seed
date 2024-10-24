import locale from '@salesforce/i18n/locale';

export default class DateUtils {
    static toUTC(d) {
        const timezoneOffset = d.getTimezoneOffset() * 60000;
        let utc = new Date(d.getTime() + timezoneOffset);
        utc.setDate(utc.getDate() - 1);
        return utc;
    }

    static getFormattedDate(date, param = {month: '2-digit', day: '2-digit', year: 'numeric'}, loc = locale) {
        return new Intl.DateTimeFormat(loc, param).format(new Date(date));
    }

    static toTimeZoneAdjustedISOString(date) {
        const d = date || new Date();
        const offset = d.getTimezoneOffset();
        const adjustedDate = new Date(d.getTime() - (offset*60000))
        return adjustedDate.toISOString().split('T')[0]
    }
}