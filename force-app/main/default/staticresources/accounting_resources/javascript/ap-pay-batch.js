AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";
    vex.defaultOptions.className = 'vex-theme-default';
    
    var currencyFormatterProxy = ASModule.currencyFormatterProxy;
    var sumColumnAndSetTotal = ASModule.sumColumnAndSetTotal;
    var numberFormatter = ASModule.numberFormatter;

    ASModule.sumBatchCheckCountAndAmount = function() {
        sumColumnAndSetTotal('tr:has(input:checked) > td > [id$="totalAmount"]','[id$="batchTotalAmount"],[id$="totalTotalAmount"]');
        sumColumnAndSetTotal('tr:has(input:checked) > td > [id$="discountAmount"], tr:has(input:checked) > td > [id$="discountAmountInput"]','[id$="batchDiscountAmount"],[id$="discountTotalAmount"]');
        sumColumnAndSetTotal('tr:has(input:checked) > td > [id$="creditMemoAmount"]','[id$="batchCreditMemoAmount"],[id$="totalCreditMemoAmount"]');
        sumColumnAndSetTotal('tr:has(input:checked) > td > [id$="netAmount"]','[id$="batchNetAmount"],[id$="netTotalAmount"]');

        $('[id$="checkCount"],[id$="checkCountTable"]').text($('[id$="thePageBlockSectionCash"] input:checked').length);
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

    ASModule.pageLoad = function() {
        $('[id$="Amount"]').each(function() {
            $(this).text(currencyFormatterProxy($(this).text()));
        });

        if (ASModule.isMultiCurrencyEnabled) {
            $('[id$="cdDate"]').each(function() {
                $(this).change(function() {
                    var rowNum = $(this).attr('id').split(":")[5];
                    var currRateId = "checkTable\\:" +   rowNum + "\\:conversionRate";
                    ASModule.queryCurrencyConversionRate($(this).val(), currRateId);
                });
            });
        }

        ASModule.sumBatchCheckCountAndAmount();
        $('[id$="bankAccount"]').prop("readonly", true);
    };

    ASModule.recalculateDiscount = function (self) {
        if (self) {
            let commonPartId = self.id.substring(0, self.id.lastIndexOf(':') + 1);
            let totalAmountHolder = document.getElementById(commonPartId + 'totalAmount');
            let creditMemoAmountHolder = document.getElementById(commonPartId + 'creditMemoAmount');
            let netAmountHolder = document.getElementById(commonPartId + 'netAmount');
            if (netAmountHolder && creditMemoAmountHolder && totalAmountHolder && totalAmountHolder.innerText) {
                let totalAmount = AcctSeed.ASModule.numberParser(totalAmountHolder.innerText);
                let creditMemoAmount = creditMemoAmountHolder.innerText && AcctSeed.ASModule.numberParser(creditMemoAmountHolder.innerText) || 0;

                netAmountHolder.innerText = AcctSeed.ASModule.currencyFormatterProxy(totalAmount - creditMemoAmount - AcctSeed.ASModule.numberParser(self.value));
            }
            AcctSeed.ASModule.sumBatchCheckCountAndAmount();
        }
    };

    ASModule.aggregateByPayeeChanged = function() {
        aggregateByChanged();
        /*
        vex.dialog.buttons = {
            NO: {
                text: 'Cancel',
                type: 'button',
                className: 'vex-dialog-button-primary',
                click: function noClick () {
                    vex.close()
                }
            },
            YES: {
                text: 'Continue',
                type: 'button',
                className: 'vex-dialog-button-secondary',
                click: function yesClick () {
                    this.value = true;
                    aggregateByChanged();
                }
            }
        };

        vex.dialog.defaultOptions = {
            buttons: [
                vex.dialog.buttons.NO,
                vex.dialog.buttons.YES
            ]
        };

        vex.dialog.confirm({
            message: WRN_UNSAVED_CHANGES,
            callback: function(value) {
                //revert the checkbox value becuase the user cancelled
                if (!value) {
                    if($(checkbox).is(":checked")){
                        $(checkbox).prop("checked", false);
                    }else{
                        $(checkbox).prop("checked", true);
                    }
                }
            }
        });
        */
    };


    $(document).ready(function() {
        ASModule.pageLoad();
    });

    return ASModule;



        
    

})(window, document, $j, AcctSeed.ASModule);