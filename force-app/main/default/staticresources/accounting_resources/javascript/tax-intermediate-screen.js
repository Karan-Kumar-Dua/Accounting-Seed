AcctSeed.ASModule = (function(window, document, $, ASModule) {

    var taxTable;
    var currencyFormatterProxy = ASModule.currencyFormatterProxy;
    var numberParser = ASModule.numberParser;

    var formatTable = function() {
        taxTable = $('[id$="taxTable"]').DataTable({
            "paging": true,
            "lengthChange": false,
            "pageLength": 25,
            "searching": false,
            "ordering": false,
            "aoColumnDefs": [{
                "aTargets": [0,1,2,3,4,5],
                "defaultContent": "",
            }]
        });


        $('#spinner').css('display', 'none');
        $('[id$="taxTable"]').css('visibility', 'visible');
    };

    var setAmountPosition = function () {
        var tdWidth = $('[id$="amountPosition"]').width();
        $('.setBlockPosition').each(function () {
        $(this).width(tdWidth);
        });
    }

    ASModule.hideSpinner = function() {
        $('#spinner').css('display', 'none');
        $('[id$="taxTable"]').css('display', 'none');
    };

    ASModule.pageLoad = function() {
        $('[id$="Amount"]').each(function () {
            $(this).text(currencyFormatterProxy($(this).text(), 4));
        });
        $('[id$="Amounts"]').each(function () {
            $(this).text(currencyFormatterProxy($(this).text()));
        });
        $('[id$="TaxRate"]').each(function () {
            $(this).text(numberParser($(this).text(), -6) + '%');
        });
    }

    $(function() {
        formatTable();
    });

    $(document).ready(function ($) {
        ASModule.pageLoad();
        setAmountPosition();
    });

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);
