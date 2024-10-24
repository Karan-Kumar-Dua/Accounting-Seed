AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    $(window).on('load', function(){
        $('#loader1').css("display", "none");
        $('[id*=attachButton]').show();
    });

    $(function() {
        $('[id*=attachButton]').hide();
    });

    return ASModule;
    
})(window, document, $j, AcctSeed.ASModule);