AcctSeed.ASModule = (function(window, document, $, ASModule, Intl) {
    "use strict";
    
    var defaultLocale = ASModule.defaultLocale !== undefined ? ASModule.defaultLocale  : 'en-US';
    var defaultCurrency = ASModule.defaultCurrency !== undefined ? ASModule.defaultCurrency : 'USD';
    var isMultiCurrencyEnabled =
        ASModule.isMultiCurrencyEnabled !== undefined
            ? ((ASModule.isMultiCurrencyEnabled == 'true') ? true : false)
            : false;
    
    var dateFormat = new Intl.DateTimeFormat(
        defaultLocale, {
            localeMatcher: 'lookup',
            year: 'numeric',
            month: 'numeric',
            day: 'numeric'
        });

    var currencyIsoCode = (ASModule.currencyIsoCode) ? ASModule.currencyIsoCode : 'USD';

    var formatCurrencySymbol = function(formattedCurrency) {
        var currencySymbolOrCode = formattedCurrency.replace(/(\d|\.|\,|\-|\s)+/gi, '');
        var codeAndValueSeparator = isMultiCurrencyEnabled ? ' ' : '';

        formattedCurrency = formattedCurrency.replace(currencySymbolOrCode, '');
        formattedCurrency = currencySymbolOrCode + codeAndValueSeparator + formattedCurrency.trim();

        return formattedCurrency;
    };

    ASModule.currencyFormatter = function(value, exp) {
        exp = exp !== undefined ? exp : 2;
        var currencyFormat = Intl.NumberFormat(
            defaultLocale, {
                style: 'currency',
                minimumFractionDigits: exp,
                maximumFractionDigits: exp,
                localeMatcher: 'lookup',
                currency: defaultCurrency,
                currencyDisplay: 'symbol'
            });
        return formatCurrencySymbol(currencyFormat.format(value)).replace(/US\$|A\$/g,'$').replace(/THB/g,'฿');
    };

    ASModule.currencyFormatterMC = function(value, exp, selectedCurrencyIsoCode) {
        exp = exp !== undefined ? exp : 2;
        currencyIsoCode = selectedCurrencyIsoCode || ASModule.currencyIsoCode || currencyIsoCode;
        var currencyFormatMC = Intl.NumberFormat(
            defaultLocale, {
                style: 'currency',
                currency: currencyIsoCode,
                minimumFractionDigits: exp,
                maximumFractionDigits: exp,
                currencyDisplay: 'code'
            }
        );

        var result = formatCurrencySymbol(currencyFormatMC.format(value));
        result = result.trim();
        //add whitespace between ISO code and value
        if (result.indexOf(currencyIsoCode) != -1) {
            result = result.replace(currencyIsoCode, currencyIsoCode + ' ');
        }

        return result;
    };

    ASModule.currencyFormatterProxy = function(value, exp, accountingNegative, selectedCurrencyIsoCode) {
        accountingNegative = accountingNegative !== undefined ? accountingNegative : true;
        var result;
        if (isMultiCurrencyEnabled) {
             result = ASModule.currencyFormatterMC(value, exp, selectedCurrencyIsoCode);
        }
        else {
            result = ASModule.currencyFormatter(value, exp);
        }
        //negative value in accounting style
        // e.g.: -EUR 300 -> (EUR 300)
        // e.g.: -$400 -> ($400)
        if (accountingNegative) {
            result = result.replace(/-(.*)/, "($1)");
        }

        return result;
    };

    /*
    * Parses Number or String value to Number format like the following
    * [-]XX.XX
    * This function allow us to save consistent state of Number values on the Javascript side of business logic
    * Use "exp" argument to control the number of decimal places
    * */
    ASModule.numberParser = function(value, exp) {
        exp = exp || -2;//by default we will have two decimal places after a decimal point
        value = (value + '').replace(/[^\d,.-]/g, '');
        var sign = value.charAt(0) === '-' ? '-' : '+';
        var minor = value.match(/[.,](\d+)$/);
        value = value.replace(/[.,]\d*$/, '').replace(/\D/g, '');
        value = Number(sign + value + (minor ? '.' + minor[1] : ''));
        value = isNaN(value) ? 0 : value;

        return Math.round10(value, exp);
    };

    ASModule.numberParserByLocale = function(value, exp) {
        exp = exp || -2;//by default we will have two decimal places after a decimal point
        var sign = value.includes('(') ? '-' : '';
        value = (value + '').replace(/[^\d,.-]/g, '');
        var example = Intl.NumberFormat(defaultLocale).format('1.1');
        var cleanPattern = new RegExp('[^-+0-9${' + example.charAt( 1 ) + '}]', 'g');

        var cleaned = (value + '').replace(cleanPattern, '');
        var normalized = cleaned.replace(example.charAt(1), '.');

        value = parseFloat(sign + normalized);
        value = isNaN(value) ? 0 : value;
        return Math.round10(value, exp);
    };

    /*
    * Use that function for output in the current User locale
    * ex: 20.58 will be converted to 20,58 in German User Locale
    * Use "exp" argument to control the number of decimal places
    * */
    ASModule.numberFormatter = function(value, exp, accountingNegative) {//Number value expected here
        accountingNegative = accountingNegative !== undefined ? accountingNegative : false;
        exp = exp !== undefined ? exp : 2;
        //For any locales where a thousands separator is comma or dot we will use use grouping separators in formatted numbers
        //For locales where a thousands separator is whitespace - we will not use grouping separators in formatted numbers
        var useGrouping = (defaultLocale === 'fr-FR') ? false : true;
        var numberFormat = Intl.NumberFormat(
            defaultLocale, {
                style: 'decimal',
                minimumFractionDigits: exp,
                maximumFractionDigits: exp,
                localeMatcher: 'best fit',
                useGrouping: useGrouping
            });
        return accountingNegative ? numberFormat.format(value).replace(/-(.*)/, "($1)") : numberFormat.format(value);
    };

    ASModule.dateFormatter = function(value) {
        return dateFormat.format(new Date(value));
    };

    ASModule.sumColumnAndSetTotal = function(sourceSelector, destinationSelector) {
        var total = 0;
        var notEmptyValue = false;

        $(sourceSelector).each(function(index,value) {
            var cellNum = 0;

            if($(value).text().charAt(0) === '(' ) {
                cellNum = ASModule.numberParser($(value).text().replace(/\([^\d]*([\d.,]+)\)/g, '-$1'));
            }
            else if ($(value).text() !== "") {
                cellNum = ASModule.numberParser($(value).text());
                notEmptyValue = true;
            }
            else if ($(value).val() !== "") {
                cellNum = ASModule.numberParser($(value).val());
                notEmptyValue = true;
            }
            total += cellNum;
        });

        var result = notEmptyValue ? ASModule.currencyFormatterProxy(total) : '';
        $(destinationSelector).text(result);
    };

    return ASModule;
    
})(window, document, $j, AcctSeed.ASModule, (Intl || IntlPolyfill));