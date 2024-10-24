AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";
    var dateFormatter = ASModule.dateFormatter;
    var numberFormatter = ASModule.numberFormatter;

    ASModule.setBeginningBalance = function() {
        var bankAccountId = $('[id$="bankAccount"]').val();
        var selectedLedgerId = $('[id$="selectedLedger"]').val();

        if (bankAccountId.length > 0 && selectedLedgerId.length > 0) {
            Visualforce.remoting.Manager.invokeAction(
                ASModule.getBeginningBalanceRemoteAction,
                bankAccountId,
                selectedLedgerId,
                function(result, event) {
                    if (event.status) {
                        $('[id$="beginningBalance"]').val(result.beginningBalance !== undefined ? numberFormatter(result.beginningBalance) : result.beginningBalance);
                        $('[id$="startDate"]').val(result.startDate !== undefined ? dateFormatter(result.startDate) : result.startDate);
                        $('[id$="glVariable1_lkid"]').val(result.glav1);
                        $('[id$="glVariable1"]').val(result.glav1Name);
                        $('[id$="glVariable2_lkid"]').val(result.glav2);
                        $('[id$="glVariable2"]').val(result.glav2Name);
                        $('[id$="glVariable3_lkid"]').val(result.glav3);
                        $('[id$="glVariable3"]').val(result.glav3Name);
                        $('[id$="glVariable4_lkid"]').val(result.glav4);
                        $('[id$="glVariable4"]').val(result.glav4Name);
                    }
                }, {escape : false}
            );
        }
        else {
            $('[id$="beginningBalance"]').val('');
            $('[id$="startDate"]').val('');
            $('[id$="glVariable1"]').val('');
            $('[id$="glVariable1_lkid"]').val('');
            $('[id$="glVariable2"]').val('');
            $('[id$="glVariable2_lkid"]').val('');
            $('[id$="glVariable3"]').val('');
            $('[id$="glVariable3_lkid"]').val('');
            $('[id$="glVariable4"]').val('');
            $('[id$="glVariable4_lkid"]').val('');
        }

    };

    $(document).ready(function($) {
        ASModule.setBeginningBalance();
    });

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);