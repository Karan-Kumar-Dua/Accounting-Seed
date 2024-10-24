AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    var isAvalaraTaxCalcEnabled =
        ASModule.isAvalaraTaxCalcEnabled !== undefined
            ? ((ASModule.isAvalaraTaxCalcEnabled == 'true') ? true : false)
            : false;
    var numberFormatter = ASModule.numberFormatter;
    var numberParser = ASModule.numberParser;

    ASModule.getBillUnitCostValue = function(lineNumber) {
        return $('[id$=":' + lineNumber + ':billLinesRate"]').val();
    };

    ASModule.getBillQuantityValue = function(lineNumber) {
        return $('[id$=":' + lineNumber + ':billLinesHoursUnits"]').val();
    };

    ASModule.getTaxRateValue = function(lineNumber) {
        return $('[id$=":' + lineNumber + ':taxRate"]').val();
    };

    ASModule.getSubTotalValue = function(lineNumber) {
        return $('[id$=":' + lineNumber + ':subTotalWithCurrency"]').text();
    };

    ASModule.getTaxAmountValue = function(lineNumber) {
        return $('[id$=":' + lineNumber + ':salesTaxWithCurrency"]').text();
    };

    ASModule.getAvalaraTaxAmountValue = function(lineNumber) {
        return $('[id$=":' + lineNumber + ':salesTaxAvalaraWithCurrency"]').text();
    };

    ASModule.getTaxInclusive = function(lineNumber) {
        var val = $('[id$=":' + lineNumber + ':taxInclusive"]').val();
        return val === 'true' ? true : false;
    };

    ASModule.calculateTotal = function() {
        $('[id$="subTotalWithCurrency"]').each(function () {
            var lineNumber = this.id.split(":")[5];
            if (ASModule.getBillUnitCostValue(lineNumber) != undefined && ASModule.getBillQuantityValue(lineNumber) != undefined) {
                var cost = numberParser(ASModule.getBillUnitCostValue(lineNumber), -6);
                var quantity = numberParser(ASModule.getBillQuantityValue(lineNumber), -6);
                if (ASModule.getTaxInclusive(lineNumber)) {
                    var taxRate = numberParser(ASModule.getTaxRateValue(lineNumber), -6);
                    var total = cost * quantity;
                    $(this).text(total / (1 + taxRate));
                } else {
                    $(this).text(cost * quantity);
                }
            }
            else {
                $(this).text(numberParser($(this).text()));
            }
        });

        $('[id$="salesTaxWithCurrency"]').each(function () {
            var lineNumber = this.id.split(":")[5];
            if (ASModule.getBillUnitCostValue(lineNumber) != undefined && ASModule.getBillQuantityValue(lineNumber)!= undefined && ASModule.getTaxRateValue(lineNumber) != undefined) {               
                var taxRate = numberParser(ASModule.getTaxRateValue(lineNumber), -6);
                var cost = numberParser(ASModule.getBillUnitCostValue(lineNumber), -6);
                var quantity = numberParser(ASModule.getBillQuantityValue(lineNumber), -6);
                if (ASModule.getTaxInclusive(lineNumber)) {
                    var total = cost * quantity;
                    var subtotal = total / (1 + taxRate);
                    $(this).text(total - subtotal);
                } else {
                    $(this).text(taxRate * cost * quantity);
                }
            }
            else {
                $(this).text(numberParser($(this).text()));
            }
        });

        $('[id$="billAmountWithCurrency"]').each(function () {
            var lineNumber = this.id.split(":")[5];
            if ($('[id$=":' + lineNumber + ':subTotalWithCurrency"]').length > 0 && !isAvalaraTaxCalcEnabled) {
                if (ASModule.getSubTotalValue(lineNumber) != undefined && ASModule.getTaxAmountValue(lineNumber) != undefined) {
                    if (ASModule.getTaxInclusive(lineNumber)) {
                        $(this).text(numberParser(ASModule.getBillUnitCostValue(lineNumber), -6) * numberParser(ASModule.getBillQuantityValue(lineNumber), -6));
                    } else {
                        $(this).text(numberParser(ASModule.getSubTotalValue(lineNumber), -6) + numberParser(ASModule.getTaxAmountValue(lineNumber), -6));
                    }
                }
            } else {
                if (ASModule.getBillUnitCostValue(lineNumber) != undefined && ASModule.getBillQuantityValue(lineNumber) != undefined) {
                    $(this).text((numberParser(ASModule.getBillUnitCostValue(lineNumber), -6) * numberParser(ASModule.getBillQuantityValue(lineNumber), -6)) + numberParser(ASModule.getAvalaraTaxAmountValue(lineNumber), -6));
                }
            }
        });

        $('[id$="billLinesRate"], [id$="billLinesHoursUnits"]').each(function() {
            $(this).val(numberFormatter(numberParser($(this).val(), -6), 6));
        });

        $('[id$="WithCurrency"]').each(function() {
            $(this).text(numberParser($(this).text(), -6));
        });
    };

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);
