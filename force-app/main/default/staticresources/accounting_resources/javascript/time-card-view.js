 AcctSeed.ASModule = (function(window,document,$,ASModule) {
    "use strict";  

    var updateAllDayTotals = ASModule.updateAllDayTotals;

    $(document).ready(function() {
        updateAllDayTotals();
            
        $('[id*="dialog"]').dialog({
		    autoOpen: false,
		    width: 400,
			resizable: false,
			show: "blind",
			hide: "blind",
		    open: function(event, ui) { 
		        $('.ui-dialog-titlebar-close').hide(); 
		        $('.ui-dialog-titlebar').hide(); 
		    }                   
		});
		
		
		// Dialog open
		$('[id*="timeCardDay"]').mouseenter(function(event){
		    var elements = $(this).attr("id").split(":");
		    var rowIndex = elements[5];
		    var elementIndex = elements[7];
		    if ($(this).parent().attr("class") !== '') {
				var $el = $('#thePage\\:theForm\\:thePageBlock\\:pbsection\\:theTable\\:' + rowIndex + '\\:theRepeatInput\\:' + elementIndex + '\\:dialog');
				var $paren = $('#thePage\\:theForm\\:thePageBlock\\:pbsection\\:theTable\\:' + rowIndex + '\\:theRepeatInput\\:' + elementIndex + '\\:timeCardDayCell');
				$el.dialog("option","position", { my: "left top", at: "left bottom", of: $(this)});
				$el.dialog('open');
		    }
		    return false;
		});
		
		// Dialog close
		$('[id*="timeCardDay"]').mouseleave(function(){
		    var elements = $(this).attr("id").split(":");
		    var rowIndex = elements[5];
		    var elementIndex = elements[7];
			var $el = $('#thePage\\:theForm\\:thePageBlock\\:pbsection\\:theTable\\:' + rowIndex + '\\:theRepeatInput\\:' + elementIndex + '\\:dialog');
			$el.dialog('close');

		    return false;
		});
	});	
})(window,document,$j,AcctSeed.ASModule);