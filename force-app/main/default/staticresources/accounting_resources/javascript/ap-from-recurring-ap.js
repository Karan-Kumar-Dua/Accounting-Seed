AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    var numberFormatter = ASModule.numberFormatter;
    var numberParser = ASModule.numberParser;

    ASModule.getPayableAmountValue = function(lineNumber) {
        return $('[id$=":' + lineNumber + ':payableAmount"]').val();
    };

    ASModule.getPayableQuantityValue = function(lineNumber) {
        return $('[id$=":' + lineNumber + ':payableQuantity"]').val();
    };

    ASModule.getTaxRateValue = function(lineNumber) {
        return $('[id$=":' + lineNumber + ':taxRate"]').val();
    };

    ASModule.getSubTotalValue = function(lineNumber) {
        return $('[id$=":' + lineNumber + ':subTotalWithCurrency"]').text();
    };

    ASModule.getTaxAmountValue = function(lineNumber) {
        return $('[id$=":' + lineNumber + ':taxAmountWithCurrency"]').text();
    };

    ASModule.getTaxInclusive = function(lineNumber) {
        var val = $('[id$=":' + lineNumber + ':taxInclusive"]').val();
        return val === 'true' ? true : false;
    };

    ASModule.calculateTotal = function() {
        $('[id$="subTotalWithCurrency"]').each(function () {
            var lineNumber = this.id.split(":")[5];
            if (ASModule.getPayableAmountValue(lineNumber) != undefined && ASModule.getPayableQuantityValue(lineNumber) != undefined) {
                var amount = numberParser(ASModule.getPayableAmountValue(lineNumber), -6);
                var quantity = numberParser(ASModule.getPayableQuantityValue(lineNumber), -6);
                if (ASModule.getTaxInclusive(lineNumber)) {
                    var taxRate = numberParser(ASModule.getTaxRateValue(lineNumber), -6);
                    var total = amount * quantity;
                    $(this).text(total / (1 + taxRate));
                } else {
                    $(this).text(amount * quantity);
                }
            }
            else {
                $(this).text(numberParser($(this).text()));
            }
        });

        $('[id$="taxAmountWithCurrency"]').each(function () {
            var lineNumber = this.id.split(":")[5];
            if (ASModule.getPayableAmountValue(lineNumber) != undefined && ASModule.getPayableQuantityValue(lineNumber)!= undefined && ASModule.getTaxRateValue(lineNumber) != undefined) {
                var taxRate = numberParser(ASModule.getTaxRateValue(lineNumber), -6);
                var amount = numberParser(ASModule.getPayableAmountValue(lineNumber), -6);
                var quantity = numberParser(ASModule.getPayableQuantityValue(lineNumber), -6);
                if (ASModule.getTaxInclusive(lineNumber)) {
                    var total = amount * quantity;
                    var subtotal = total / (1 + taxRate);
                    $(this).text(total - subtotal);
                } else {
                    $(this).text(taxRate * amount * quantity);
                }
            }
            else {
                $(this).text(numberParser($(this).text()));
            }
        });

        $('[id$="apAmountWithCurrency"]').each(function () {
            var lineNumber = this.id.split(":")[5];
            if ($('[id$=":' + lineNumber + ':subTotalWithCurrency"]').length > 0) {
                if (ASModule.getSubTotalValue(lineNumber) != undefined && ASModule.getTaxAmountValue(lineNumber) != undefined) {
                    if (ASModule.getTaxInclusive(lineNumber)) {
                        $(this).text(numberParser(ASModule.getPayableAmountValue(lineNumber), -6) * numberParser(ASModule.getPayableQuantityValue(lineNumber), -6));
                    } else {
                        $(this).text(numberParser(ASModule.getSubTotalValue(lineNumber), -6) + numberParser(ASModule.getTaxAmountValue(lineNumber), -6));
                    }
                }
            } else {
                if (ASModule.getPayableAmountValue(lineNumber) != undefined && ASModule.getPayableQuantityValue(lineNumber) != undefined) {
                    $(this).text(numberParser(ASModule.getPayableAmountValue(lineNumber), -6) * numberParser(ASModule.getPayableQuantityValue(lineNumber), -6));
                }
            }
        });

        $('[id$="payableAmount"], [id$="payableQuantity"]').each(function() {
            $(this).val(numberFormatter(numberParser($(this).val(), -6), 6));
        });

        $('[id$="WithCurrency"]').each(function() {
            $(this).text(numberParser($(this).text(), -6));
        });

    };

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);
