AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    ASModule.checkControl = function(options) {
        if (options.checked && $('[id$=deposit]').attr("id") === options.id) {
            $('[id$=cashReceipt]').prop('checked', true);
        }
        if (!options.checked && $('[id$=cashReceipt]').attr("id") === options.id) {
            $('[id$=deposit]').prop('checked', false);
        }
    };

    return ASModule;
})(window, document, $j, AcctSeed.ASModule);