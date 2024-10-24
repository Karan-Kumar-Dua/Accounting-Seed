AcctSeed.ASModule = (function(window,document,$,ASModule) {
    "use strict";
    
    $(document).ready(function () {
        $("body").keydown(function (e) {
            if (e.keyCode === 13 && !$(":focus").is("textarea")) {
                ASModule.saveback();
            }
        });
    });

    return ASModule;
    
})(window,document,$j,AcctSeed.ASModule);