AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";
    
    var sumColumnAndSetTotal = ASModule.sumColumnAndSetTotal;
    var numberParser = ASModule.numberParser;
    var currencyFormatterProxy =  ASModule.currencyFormatterProxy;

    ASModule.updateExpenseAmount = function() {
        sumColumnAndSetTotal('[id$="expenseAmount"]','[id$="expenseFooterAmount"]');
        sumColumnAndSetTotal('[id$="expenseFooterAmount"],[id$="mileageTotalAmount"]','[id$="expenseTotalAmount"]');
    };

    ASModule.updateMileageAmount = function() {
        
        $('[id$="mileageAmount"]').each(function(){
            $(this).text(currencyFormatterProxy(numberParser($(this).text())));
        });
        sumColumnAndSetTotal('[id$="mileageAmount"]','[id$="mileageTotalAmount"]');
        sumColumnAndSetTotal('[id$="expenseFooterAmount"],[id$="mileageTotalAmount"]','[id$="expenseTotalAmount"]');
    };
 
    ASModule.updateMileageTotal = function() {
        var total = 0;
        var cellNum;

        $('[id$="mileage"]').each(function(index,value) {
            cellNum = 0;
            if ($(value).val() !== "") {
                cellNum = !isNaN(numberParser($(value).val())) ? numberParser($(value).val()) : 0;
            }
            total += cellNum;
        });

        $('[id$="mileageTotal"]').text(ASModule.numberFormatter(total));
    };

    $(document).ready(function() {
        $("body").keydown(function(e) {
            if (e.keyCode === 13 && !$(":focus").is("textarea")) {
                AcctSeed.ASModule.saveAndClose();
            }
        });
        $('[id$="expenseAmount"]').attr('maxlength','10');
        $('[id$="miles"]').attr('maxlength','8');

        ASModule.updateExpenseAmount();
        ASModule.updateMileageAmount();
        ASModule.updateMileageTotal();
    });

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);