AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    var currencyFormatterProxy = ASModule.currencyFormatterProxy;
    var currencyFormatter = ASModule.currencyFormatter;
    var numberFormatter = ASModule.numberFormatter;
    var isMultiCurrencyEnabled = ASModule.isMultiCurrencyEnabled;

    ASModule.pageLoad = function() {
        $('[id$="Amount"], [id$="totalAmount"]').each(function() {
            $(this).text(currencyFormatterProxy($(this).text()));
        });
        $('[id$="WithCurrency"], [id$="totalWithCurrency"]').each(function(){
            if (isMultiCurrencyEnabled == 'true') {
                $(this).text(numberFormatter($(this).text()));
            }
            else {
                $(this).text(currencyFormatter($(this).text()));
            }
        });
    };

    ASModule.setCurrentCurrency = function() {
        $('[id$="differentCurrency"]').each(function() {
            $(this).text(currencyFormatterProxy($(this).text(), 2, true, $(this).children().val()));
        });
    };

    $(function() {
        ASModule.pageLoad();
        ASModule.setCurrentCurrency();
    });

    return ASModule;
    
})(window, document, $j, AcctSeed.ASModule);