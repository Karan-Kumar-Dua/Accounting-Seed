AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    $(document).ready(function () {
        $('[id$="inputEmployee"], [id$="inputLedger"]').change(function () {
            ASModule.reRenderTimeCardList();
        });
    });
    return ASModule;

})(window, document, $j, AcctSeed.ASModule);
