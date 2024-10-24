import locale from '@salesforce/i18n/locale';

export default class CommonUtils {

  static getRecordViewPath = (recordId) => '/lightning/r/' + recordId + '/view';

  static getPackageQualifier = fieldApiName => {
    let subString = fieldApiName.includes('__r') ?
      fieldApiName.substring(0, fieldApiName.indexOf('__r')) : fieldApiName.substring(0, fieldApiName.indexOf('__c'));
    return subString.includes('__') ? fieldApiName.substring(0, fieldApiName.indexOf('__')) + '__' : '';
  }

  static copyObject = (source) => JSON.parse(JSON.stringify(source));

  static getDataValue = (field, obj) => {
    return field !== undefined && obj !== undefined ? field.split('.').reduce((o,i)=> !!o ? o[i] : undefined, obj) : null;
  }

  static setDataValue = (field, obj, value) => {
    return field.split('.').reduce((o,f,i,a)=> {
      if (i === a.length-1) {
        o[f] = value;
      }
        return o[f];
    }, obj);
  }

  static mergeObjects = (target, source) => {
    for (const key of Object.keys(source)) {
      if (source[key] instanceof Object && key in target) {
        Object.assign(source[key], CommonUtils.mergeObjects(target[key], source[key]));
      }
    }
    Object.assign(target || {}, source)
    return target
  }

  static isValue = (val) => val !== undefined && val !== null;
  
  // temp fix for Platform event API name imported in LWC uses “c” instead of “e” as suffix
  static getObjectWithQualifier(val, pq) {
    if (!val.fieldApiName.startsWith(pq)) {
      val.fieldApiName = pq + val.fieldApiName;
    }
    if (!val.objectApiName.startsWith(pq)) {
      val.objectApiName = pq + val.objectApiName;
    }
    return val;
  }

  // round to two decimal places
  static round = (val) => CommonUtils.clearZeroValue(Math.round(val * 100) / 100);

  // remove minus sign for zero value
  static clearZeroValue = val => (val < 0 ? val : Math.abs(val));

  static getFormattedNumber = (value, fraction = 2) => new Intl.NumberFormat(locale, { minimumFractionDigits: fraction}).format(value);

  static getFormattedCurrency = (value=0, currencyIsoCode='USD', isMultiCurrencyOrg=false) => {
    const formatter = new Intl.NumberFormat(locale, {
      style: 'currency',
      currency: currencyIsoCode,
      currencyDisplay: isMultiCurrencyOrg ? 'code' : 'symbol'
    });

    let formattedCurrency = formatter.format(value);
    const currencySymbolOrCode = formattedCurrency.replace(/(\d|\.|,|-|\s)+/gi, '');
    const codeAndValueSeparator = isMultiCurrencyOrg ? ' ' : '';
    const currencyCode = currencySymbolOrCode + codeAndValueSeparator;
    formattedCurrency = formattedCurrency.replace(currencySymbolOrCode, '');
    formattedCurrency = currencyCode + formattedCurrency.trim();

    return formattedCurrency;
  }

  static setObjectValue(object, path, value) {
    const way = path.replace(/\[/g, '.').replace(/\]/g, '').split('.'),
        last = way.pop();

    way.reduce(function (accum, value, index, array) {
      return accum[value] = accum[value] || (isFinite(index + 1 in array ? array[index + 1] : last) ? [] : {});
    }, object)[last] = value;
    return object;
  }

  static computeClasses = (classes = []) => {
    return classes.filter((item, index, array) => !!item && array.indexOf(item) === index).join(' ');
  };

  static getFieldValue = (field) => {
    let value;
    if (field.type == 'toggle') {
      value = field.checked;
    } else {
      value = field.value;
    }
    return value;
  }

  /**
   * Generates possible 12H start times in hour increments starting
   * with 12:00 AM and ending with 11:00 PM. Values are 0-23 as
   * this is used for cron job scheduling. Displayed in the
   * "Preferred Start Time" and "Run Deletion Job At" comboboxes
   */
  static startTimes = (timesToExclude) => {
    const times = [];
    let currentTime;

    for (let i = 0; i < 24; i++) {
      currentTime = `${(i % 12 == 0 ? 12 : i % 12)}:00 ${(i < 12) ? 'AM' : 'PM'}`;
      if (!timesToExclude || !timesToExclude.length || !timesToExclude.includes(currentTime)) {
        times.push({
          label: currentTime,
          value: i.toString()
        });
      }
    }
    return times;
  }

  static intSeqGenerator(seed = 0) {
    function* generator(i) {
      while (true) {
        yield i++;
      }
    }
    return generator(seed);
  }

}