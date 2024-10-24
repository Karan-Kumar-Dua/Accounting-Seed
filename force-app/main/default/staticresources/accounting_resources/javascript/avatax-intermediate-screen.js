AcctSeed.ASModule = (function(window, document, $, ASModule) {

    var currencyFormatterProxy = ASModule.currencyFormatterProxy;

    ASModule.pageLoad = function() {
        $(".jsFormattedCurrency").each(function () {
            $(this).text(currencyFormatterProxy($(this).text(), 2, false));
        });
    };

    $(document).ready(function() {
        ASModule.pageLoad();
    });

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);
