AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    if (typeof ASModule.CheckBoxSet != 'undefined') {
        ASModule.billingCheckBoxes = null;
        var amountParams = {};
        var billingParams = {};
        var currencyFormatterProxy = ASModule.currencyFormatterProxy;
        var numberParser = ASModule.numberParser;
        var numberParserByLocale = ASModule.numberParserByLocale;

        amountParams.selectors = {
            full: "span[id$=\"amount-full\"], th.amount-full>div>span",
            row: "td.amount-row>span",
            rowDate: "td.amount-row-date input",
            rowQuantity: "td.amount-row-quantity input, td.amount-row-quantity span",
            rowPrice: "td.amount-row-price input, td.amount-row-price span",
            rowTaxAmount: "td.amount-row-tax span",
            rowTotal: "td.amount-row-total",
            rowTaxRate: "input[id$=\"lineTaxRate\"]"
        };

        amountParams.methods = {
            update: function() {
                var amountFull = 0.0;
                $(amountParams.selectors.row).each(function() {
                    var dataRow = $(this).parents("tr.dataRow").first();
                    var rAmount = $(this);
                    var rDate = dataRow.find(amountParams.selectors.rowDate);
                    var rQuantity = dataRow.find(amountParams.selectors.rowQuantity);
                    var rPrice = dataRow.find(amountParams.selectors.rowPrice);
                    var rTax = dataRow.find(amountParams.selectors.rowTaxAmount);
                    var rTotal = dataRow.find(amountParams.selectors.rowTotal);
                    var rTaxRate = dataRow.find(amountParams.selectors.rowTaxRate);
                    if (!rDate.is("[disabled]")) {//Date field is always disable when checkbox is not checked
                        //quantity and price elements can be input or span
                        var rQuantityValue = (rQuantity.is("input")) ? rQuantity.val() : rQuantity.text();
                        var rPriceValue = (rPrice.is("input")) ? rPrice.val() : rPrice.text();
                        var rTaxRateValue;
                        var rTaxValue = numberParserByLocale(rTax.text(), -2);
                        var amountRow = numberParserByLocale(rQuantityValue, -4) * numberParserByLocale(rPriceValue, -4);

                        if (rTaxRate.length) {
                            rTaxRateValue = rTaxRate[0].value != '' ? rTaxRate[0].value : 0;
                        }
                        if (rTaxRateValue != undefined && rTaxRateValue != 0) {
                            rTaxValue = amountRow * numberParser(rTaxRateValue, -4);
                        }
                        else if (rTaxRateValue != undefined) {
                            rTaxValue = 0
                        }
                        rAmount.text(currencyFormatterProxy(amountRow));
                        var total = amountRow + rTaxValue;
                        amountFull += total;
                        rTotal.text(currencyFormatterProxy(total));
                        rTax.text(currencyFormatterProxy(rTaxValue));
                    }
                    else {
                        rAmount.text('');
                        rTotal.text('');
                        rTax.text('');
                    }
                });
                $(amountParams.selectors.full).text(currencyFormatterProxy(amountFull));
            },
            rebind: function() {
                $(amountParams.selectors.rowQuantity + ", " + amountParams.selectors.rowPrice).bind("change", function() {
                    amountParams.methods.update();
                });
            }
        };

        billingParams.defaultFieldValues = {};
        billingParams.selectors = {
            main: ".rbLines_checkbox_all",
            child: ".rbLines_checkbox"
        };
        billingParams.methods = {
            load: function() {
                $(billingParams.selectors.child).each(function() {
                    var dataRow = $(this).parents("tr.dataRow").first();
                    dataRow.find("input:not(" + billingParams.selectors.child + "):not(.readonly), textarea").each(function() {
                        billingParams.defaultFieldValues[this.id] = this.value;
                    });

                    //Fix for filtered lookups
                    dataRow.find("img.closeIcon").each(function() {
                        var icon = $(this);
                        var parentCont = $(this).parent();
                        var lkpIcon = parentCont.find("a>img");
                        var inputs = $(this).parent().children("input.readonly");
                        var valueInput = $(inputs[0]);
                        var emptyInput = $(inputs[1]);
                        emptyInput.css("width", valueInput.css("width"));
                        parentCont.css("width",
                            (
                                parseInt(valueInput.css("width")) +
                                parseInt(valueInput.css("border-left-width")) +
                                parseInt(valueInput.css("border-right-width")) +
                                parseInt(icon.css("width")) +
                                parseInt(icon.css("margin-right")) +
                                parseInt(lkpIcon.css("width")) +
                                parseInt(lkpIcon.css("margin-right"))
                            ) + "px"
                        ).css("display", "inline-block");
                    });
                });
                amountParams.methods.update();
            },
            click: function(target) {
                var dataRow = $(target).parents("tr.dataRow").first();
                if (target.checked) {
                    dataRow.find("input:text, textarea").removeAttr("disabled");
                    dataRow.find("a>img").parent().css("opacity", "1");

                    //Fix for filtered lookups
                    dataRow.find("td.dataCell>span.lookupInput>img.closeIcon").each(function() {
                        var icon = $(this);
                        var inputs = icon.parent().children("input.readonly");
                        var valueInput = $(inputs[0]);
                        var emptyInput = $(inputs[1]);
                        var recordId = icon.parent().parent()
                            .children('input[type="hidden"][id$="_lkid"]').get(0).value;
                        if (recordId.match(/^0+$/g)) {
                            icon.css("display", "none");
                            valueInput.css("display", "none");
                            emptyInput.css("display", "inline-block");
                        }
                        else {
                            var recordName = icon.parent().parent()
                                .children('input[type="hidden"][id$="_lkold"]').get(0).value;
                            emptyInput.css("display", "none");
                            valueInput.val(recordName);
                            valueInput.css("display", "inline-block");
                            icon.css("display", "inline-block");
                        }
                    });
                }
                else {
                    dataRow.find("input:not(" + billingParams.selectors.child + "):not(.readonly), textarea").each(function() {
                        $(this).val(billingParams.defaultFieldValues[this.id]);
                    });
                    dataRow.find("input:text, textarea").attr("disabled", "disabled").removeClass("error");
                    dataRow.find("a>img").parent().css("opacity", "0");
                    dataRow.find("div.errorMsg").css("display", "none");

                    //Fix for filtered lookups
                    dataRow.find("td.dataCell>span.lookupInput>img.closeIcon").each(function() {
                        var icon = $(this);
                        var inputs = icon.parent().children("input.readonly");
                        var valueInput = $(inputs[0]);
                        var emptyInput = $(inputs[1]);
                        icon.css("display", "none");
                        emptyInput.css("display", "none");
                        valueInput.val('').css("display", "inline-block");
                    });
                }
            },
            update: function() {
                amountParams.methods.update();
            },
            rebind: function() {
                amountParams.methods.rebind();
            }
        };

        $(document).ready(function() {
            if (sfdcPage.onLoadQueue.length > 0) {
                sfdcPage.executeOnloadQueue();
            }
            ASModule.billingCheckBoxes = new ASModule.CheckBoxSet(billingParams);
            ASModule.toggleSpinner(false);
        });
    }
    else {
        $.error("You must load CheckBoxSet module before using this code.");
    }

    ASModule.checkControl = function(options) {
        if (options.checked && $('[id$=deposit]').attr("id") === options.id) {
            $('[id$=cashReceipt]').prop('checked', true);
        }
        if (!options.checked && $('[id$=cashReceipt]').attr("id") === options.id) {
            $('[id$=deposit]').prop('checked', false);
        }
    };

    ASModule.toggleSpinner = function(show) {
        $(".custom-js-exec-spinner").toggle(show);
    };

    ASModule.rerenderPage = function() {
        ASModule.billingCheckBoxes = new ASModule.CheckBoxSet(billingParams);
        ASModule.toggleSpinner(false);
    };

    return ASModule;
})(window, document, $j, AcctSeed.ASModule);