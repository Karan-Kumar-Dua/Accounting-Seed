AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    var currencyFormatterProxy = ASModule.currencyFormatterProxy;
    var numberParser = ASModule.numberParser;
    var numberFormatter = ASModule.numberFormatter;

    ASModule.updateAmount = function() {

        if ($('[id$="discountEditAmount"]') !== null) {
            var discountAmount = numberParser($('[id$="discountEditAmount"]').val());
            var taxAmount = numberParser($('[id$="taxAmount"]').length !== 0 ? $('[id$="taxAmount"]').val() : '0');
            var total = numberParser($('[id$="totalAmount"]').text());
            var creditMemoAppliedAmount = numberParser($('[id$="creditMemoAppliedAmount"]').text());

            $('[id$="payAmount"]')
                .val(numberFormatter(total - discountAmount - taxAmount - creditMemoAppliedAmount))
                .change();
        }
    };

    ASModule.calculateBalance = function() {
        var discountAmount = numberParser($('[id$="discountEditAmount"]').length !== 0 ? $('[id$="discountEditAmount"]').val() : $('[id$="discountReadAmount"]').text());
        var taxAmount = numberParser($('[id$="taxAmount"]').length !== 0 ? $('[id$="taxAmount"]').val() : '0');
        var paidAmount = numberParser($('[id$="paidAmount"]').text());
        var payAmount = numberParser($('[id$="payAmount"]').val());
        var total = numberParser($('[id$="totalAmount"]').text());
        var creditMemoAppliedAmount = numberParser($('[id$="creditMemoAppliedAmount"]').text());
        $('[id$="balanceAmount"]').text(currencyFormatterProxy(Math.round10((total - paidAmount - discountAmount - taxAmount - payAmount - creditMemoAppliedAmount), -2)));
    };

    ASModule.setCheckNumberNull = function() {
        $('[id$="checkNum"]').val('');
    };

    ASModule.refreshCheckNumber = function() {
        var bankAccountId = $('[id$="bankAccount"]').val();
        Visualforce.remoting.Manager.invokeAction(
            ASModule.getCheckNumberRemoteAction,
            bankAccountId,
            function(result, event) {
                if (event.status) {
                    $('[id$="checkNum"]').val(numberFormatter(result, 0));
                }
            }
        );
    };

    ASModule.refreshCashDisbursementBatchName = function() {
        var cashDisbursementBatchId = $('[id$="cashDisbursementBatch_lkid"]').val();
        Visualforce.remoting.Manager.invokeAction(
            ASModule.getCashDisbursementBatchRemoteAction,
            cashDisbursementBatchId,
            function(result, event) {
                if (event.status) {
                    $('[id$="cdbName"]').val(result);
                }
            }
        );
    };

    ASModule.queryCurrencyConversionRate = function(recordDate, currRateId) {

        Visualforce.remoting.Manager.invokeAction(
            ASModule.queryCurrencyConversionRateAction,
            recordDate, ASModule.currencyIsoCode, ASModule.ledgerId,
            handleResult
        );

        function handleResult(result, event) {
            if (event.status) {
                $('[id$="' + currRateId + '"]').val(result);
            }
            // TODO: Next time while working on this page will need to decide what to do in this case.
            // Perhaps this block of code is not needed at all.
            else if (event.type === 'exception') {

            }
            else {

            }
        }
    };

    ASModule.pageLoad = function() {
        $('[id$="Amount"]').each(function() {
            $(this).text(currencyFormatterProxy($(this).text()));
        });

        ASModule.calculateBalance();

        $('[id$="payAmount"], [id$="discountEditAmount"]').attr('maxlength', '10');

        //workaround for keyup event fired when onfocus occurred
        $('[id$="discountEditAmount"]').on('keyup', function() {
            if ($(this).data('val') !== undefined && $(this).data('val') !== this.value) {
                ASModule.updateAmount();
            }
            $(this).data('val', this.value);
        });

        if (ASModule.isMultiCurrencyEnabled) {
            $('[id$="cdDate"]').on('change', function() {
                ASModule.queryCurrencyConversionRate($(this).val(), 'conversionRate');
            });
        }

        $('[id$="bankAccount"]').prop("readonly", true);
    };

    $(document).ready(function() {
        ASModule.pageLoad();
    });

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);