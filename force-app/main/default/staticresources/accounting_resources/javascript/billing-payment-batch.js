AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    var currencyFormatterProxy = ASModule.currencyFormatterProxy;

    ASModule.pageLoad = function() {
        $('[id$="totalAmount"], [id$="receivedAmount"], [id$="sumTotalAmount"]').each(function() {
            $(this).text(currencyFormatterProxy($(this).text(), 2, false, $(this).attr('data-currency')));
        });
    };

    $(document).ready(function($) {
        ASModule.pageLoad();
    });

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);
