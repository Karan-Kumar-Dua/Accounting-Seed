AcctSeed.ASModule = (function(window, document, $, ASModule, Intl) {
    "use strict";
    var defaultLocale = ASModule.defaultLocale !== undefined ? ASModule.defaultLocale  : 'en-US';
    var dateFormatter = ASModule.dateFormatter;

    ASModule.calculateBillingDate = function() {
        if ($('[id$="initialBilling"]').is(':checked')) {
            $('[id$="recBillDate"]').each(function() {
                $(this).val(newDate($('[id$="billingFrequency"]').val(), $('[id$="nextDateConst"]').val()));
            });
            $('[id$="recNextBillDate"]').val(newDate($('[id$="billingFrequency"]').val(), $('[id$="nextDateConst"]').val()));
        } else {
            $('[id$="recBillDate"]').each(function() {
                $(this).val(dateFormatter($('[id$="nextDateConst"]').val()));
            });
            $('[id$="recNextBillDate"]').val(dateFormatter($('[id$="nextDateConst"]').val()));
        }
    };

    var newDate = function (frequency, oldDate) {
        var resultDate = new Date(oldDate);
        if (frequency == 'Monthly') {
            resultDate.setMonth(resultDate.getMonth() + 1);
        } else if (frequency == 'Quarterly') {
            resultDate.setMonth(resultDate.getMonth() + 3);
        } else if (frequency == 'Semi-annual') {
            resultDate.setMonth(resultDate.getMonth() + 6);
        } else if (frequency == 'Annual') {
            resultDate.setMonth(resultDate.getMonth() + 12);
        } else if (frequency == 'Weekly') {
            resultDate.setDate(resultDate.getDate() + 7);
        } else if (frequency == 'Bi-weekly') {
            resultDate.setDate(resultDate.getDate() + 14);
        }
        return dateFormatter(resultDate);
    };

    return ASModule;

})(window, document, $j, AcctSeed.ASModule, (Intl || IntlPolyfill));
