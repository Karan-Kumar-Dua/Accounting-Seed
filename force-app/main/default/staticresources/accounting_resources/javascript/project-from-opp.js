(function(window,document,$,ASModule) {
    "use strict";
	var currencyFormatterProxy = ASModule.currencyFormatterProxy;

	ASModule.clearInput = function(el) {
		var elInput = $(document.getElementById(el));
		if (elInput.is("select")) {
			elInput.val('');
		} 
		else if (elInput.is("input[type='text']")) {
			elInput.val('');
			$(document.getElementById(el + "_lkid")).val('000000000000000');
			$(document.getElementById(el + "_lkold")).val('');
			$(document.getElementById(el + "_mod")).val('0');
		}
	};

	ASModule.formatCurrency = function() {
		$('[id$="totalPrice"]').each(function() {
            $(this).text(currencyFormatterProxy($(this).text()));
        });
	};
	
})(window,document,$j,AcctSeed.ASModule);