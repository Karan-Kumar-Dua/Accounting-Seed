AcctSeed.ASModule = (function(window,document,$,ASModule) {
    "use strict";
    
    ASModule.disableCommentLinks = function() {
        $("a[id*='comments']").click(function() {
            return false;
        });
    };

    ASModule.enableCommentLinks = function() {
        $("a[id*='comments']").unbind('click');
    };

    ASModule.updateDayTotal = function(obj) {
        updateColTotals(obj);
        updateRowTotals(obj);
        ASModule.updateTotalHours();
    };

    var updateColTotals = function(obj) {
        var colNum = obj.id.split(":")[7];
        var isCalc = true;
        var currentRow = 0;
        var totalElem = document.getElementById("thePage:theForm:thePageBlock:pbsection:theTable:theRepeatHeader:" + colNum + ":dayTotal");
        var total = 0;
        var elem = document.getElementById("thePage:theForm:thePageBlock:pbsection:theTable:" + currentRow + ":theRepeatInput:" + colNum + ":timeCardDay");

        while (elem !== null) {

            var val = elem.value !== undefined ? elem.value : elem.innerHTML;
            if (!isNaN(parseFloat(val))) {
                total += parseFloat(val);
            }

            currentRow++;
            elem = document.getElementById("thePage:theForm:thePageBlock:pbsection:theTable:" + currentRow + ":theRepeatInput:" + colNum + ":timeCardDay");
        }

        totalElem.innerHTML = total.toFixed(2);
    };

    var updateRowTotals = function(obj) {
        var colNum = 0;
        var isCalc = true;
        var currentRow = obj.id.split(":")[5];
        var totalElem = document.getElementById("thePage:theForm:thePageBlock:pbsection:theTable:" + currentRow + ":lineTotal");
        var total = 0;
        var elem = document.getElementById("thePage:theForm:thePageBlock:pbsection:theTable:" + currentRow + ":theRepeatInput:" + colNum + ":timeCardDay");

        while (elem !== null) {

            var val = elem.value !== undefined ? elem.value : elem.innerHTML;
            if (!isNaN(parseFloat(val))) {
                total += parseFloat(val);
            }

            colNum++;
            elem = document.getElementById("thePage:theForm:thePageBlock:pbsection:theTable:" + currentRow + ":theRepeatInput:" + colNum + ":timeCardDay");
        }

        totalElem.innerHTML = total.toFixed(2);
    };

    ASModule.updateAllDayTotals = function() {
        var currentCol = 0;
        var currentRow = 0;

        var elem = document.getElementById("thePage:theForm:thePageBlock:pbsection:theTable:0:theRepeatInput:" + currentCol + ":timeCardDay");

        while (elem !== null) {
            updateColTotals(elem);
            currentCol++;
            elem = document.getElementById("thePage:theForm:thePageBlock:pbsection:theTable:0:theRepeatInput:" + currentCol + ":timeCardDay");
        }

        elem = document.getElementById("thePage:theForm:thePageBlock:pbsection:theTable:0:theRepeatInput:0:timeCardDay");

        while (elem !== null) {
            updateRowTotals(elem);
            currentRow++;
            elem = document.getElementById("thePage:theForm:thePageBlock:pbsection:theTable:" + currentRow + ":theRepeatInput:0:timeCardDay");
        }
    };

    ASModule.updateTotalHours = function() {
        var currentRow = 0;
        var total = 0;
        var elem = document.getElementById("thePage:theForm:thePageBlock:pbsection:theTable:" + currentRow + ":lineTotal");
        while (elem !== null) {
            total += parseFloat(elem.innerHTML);
            currentRow++;
            elem = document.getElementById("thePage:theForm:thePageBlock:pbsection:theTable:" + currentRow + ":lineTotal");
        }
        document.getElementById("thePage:theForm:thePageBlock:pbsection:theTable:timeCardTotal").innerHTML = total.toFixed(2);
        if (document.getElementById("thePage:theForm:thePageBlockHeader:projectData:pbTotalHours:timeCardTotalHeader") != null) {
            document.getElementById("thePage:theForm:thePageBlockHeader:projectData:pbTotalHours:timeCardTotalHeader").innerHTML = total.toFixed(2);
        }
    };

    $(document).ready(function() {

        ASModule.updateAllDayTotals();
        ASModule.updateTotalHours();
        $('[id$="timeCardDay"]').attr('maxlength','6');

        $(document).keydown(function(e) {
            if (e.keyCode === 13) {
                ASModule.saveAndClose();
            }
        });
    });

    return ASModule;

})(window,document,$j,AcctSeed.ASModule);