AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    vex.defaultOptions.className = 'vex-theme-default';


    ASModule.doArchiveConfirm = function({WRN_ARCHIEVE_TRANSACTIONS}) {

        vex.dialog.buttons = {
            NO: {
                text: 'Cancel',
                type: 'button',
                className: 'vex-dialog-button-primary',
                click: function noClick () {
                    vex.close()
                }
            },
            YES: {
                text: 'OK',
                type: 'button',
                className: 'vex-dialog-button-secondary',
                click: function yesClick () {
                    this.value = true;
                    doArchive();
                }
            }
        };

        vex.dialog.defaultOptions = {
            buttons: [
                vex.dialog.buttons.NO,
                vex.dialog.buttons.YES
            ]
        };

        vex.dialog.confirm({
            message: WRN_ARCHIEVE_TRANSACTIONS,
            callback: function(value) {
            }
        });
    };

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);