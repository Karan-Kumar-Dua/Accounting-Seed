AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    var currencyFormatterProxy = ASModule.currencyFormatterProxy;
    var numberFormatter = ASModule.numberFormatter;
    var numberParserByLocale = ASModule.numberParserByLocale;

    ASModule.calculateAdjustmentAmount = function() {
        var amountTotal = numberParserByLocale($('[id$="balance"]').text(), -2) - numberParserByLocale($('[id$="adjustmentAmount"]').val(), -2);
        $('[id$="payAmount"]').val(numberFormatter(amountTotal));
    };

    ASModule.pageLoad = function() {
        $('[id$="totalAmount"], [id$="receivedAmount"], [id$="balance"]').each(function() {
            $(this).text(currencyFormatterProxy($(this).text()));
        });

    };

    $(document).ready(function($) {
        ASModule.pageLoad();
        ASModule.calculateAdjustmentAmount();
    });

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);
