AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    var salesTaxTable;
    var currencyFormatterProxy = ASModule.currencyFormatterProxy;

    ASModule.disableButtonsTaxReport = function(label) {
        $('.pbButton > .btn, .pbButtonb > .btn').prop('disabled', true).val(label).toggleClass('btnDisabled');
        ASModule.hideTaxResultPageBlock();
    };

    ASModule.formatSalesTaxTable = function() {
        $('.currencyAmount').each(function () {
            if ($(this).text() != '') {
                $(this).text(currencyFormatterProxy($(this).text()));
            }
        });

        salesTaxTable = $('[id$="salesTaxTable"]').DataTable({
            "paging": false,
            "lengthChange": false,
            "pageLength": 25,
            "searching": true,
            "ordering": true
        });

    };

    ASModule.hideTaxResultPageBlock = function() {
        $('[id$="salesTaxReportResultsPageBlock"]').hide();
    };

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);