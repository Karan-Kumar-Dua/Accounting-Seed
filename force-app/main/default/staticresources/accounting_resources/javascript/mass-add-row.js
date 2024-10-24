AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    ASModule.showSearchProcessingStatus = function(label) {
        $('[id$="selectReportType"]').prop("disabled", true);
        ASModule.disableButtonsAll('Processing...');
    }

    ASModule.checkAll = function(cb) {
        var checkboxes = document.getElementsByClassName('gl-selection');
        for (var i = 0; i < checkboxes.length; i++) {
          checkboxes[i].checked = cb.checked;
        }
    };

    ASModule.uncheckSelectAll = function() {
        var checkall = document.getElementsByClassName('gl-selection-select');
        for (var i = 0; i < checkall.length; i++) {
          checkall[i].checked = false;
        }
    };

    ASModule.disableButtonsAll = function(label) {
        ASModule.disableButtons(label);
        $('[id$="search-btn"]').toggleClass('btnDisabled').prop('disabled', true).val(label);
    };

    ASModule.showHideSubTypeOptions = function() {
        var selectedReportType = $('[id$=selectReportType]').val();
        if (selectedReportType == 0) {//means "All"
            $('[id$="subtype1"]').prop("checked", false);
            $('[id$="subtype1"]').parent().css('visibility', 'hidden');
            $('[id$="subtype1"]').parent().prev().css('visibility', 'hidden');

            $('[id$="subtype2"]').prop("checked", false);
            $('[id$="subtype2"]').parent().css('visibility', 'hidden');
            $('[id$="subtype2"]').parent().prev().css('visibility', 'hidden');
        }
        else if (selectedReportType == 1) {//means "Balance Sheet"
            $('[id$="subtype1"]').parent().prev().text('Group By Sub Type');
            $('[id$="subtype1"]').parent().css('visibility', 'visible');
            $('[id$="subtype1"]').parent().prev().css('visibility', 'visible');

            $('[id$="subtype2"]').prop("checked", false);
            $('[id$="subtype2"]').parent().css('visibility', 'hidden');
            $('[id$="subtype2"]').parent().prev().css('visibility', 'hidden');
        }
        else if (selectedReportType == 2) {//means "Profit&Loss"
            $('[id$="subtype1"]').parent().prev().text('Group By Sub Type 1');
            $('[id$="subtype1"]').parent().css('visibility', 'visible');
            $('[id$="subtype1"]').parent().prev().css('visibility', 'visible');

            $('[id$="subtype2"]').parent().css('visibility', 'visible');
            $('[id$="subtype2"]').parent().prev().css('visibility', 'visible');
        }
    };

    $(document).ready(function() {
        ASModule.showHideSubTypeOptions();
    });

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);