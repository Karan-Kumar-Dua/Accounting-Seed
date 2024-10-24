AcctSeed.ASModule = (function (window, document, $, ASModule) {
    "use strict";

    vex.defaultOptions.className = 'vex-theme-default';

    ASModule.enableCashFlowStatementConfirm = function (checkbox) {

        if ($(checkbox).is(":checked")) {
            vex.dialog.confirm({
                message: 'Are you sure you want to enable Cash Flow Statement functionality?<br/><br/>' +
                    'The cash flow statement summarizes the amount of cash and cash equivalents entering and exiting the ledger. The cash flow statement requires that ALL cash receipts, cash disbursement, and a subset of journal entry lines must have a new cash flow category field populated. The cash flow statement creates and manages another set of financial cubes and may result in additional data storage. Once the cash flow statement is enabled, you will need to contact Accounting Seed Support to disable. Please review the Accounting Seed Knowledge Base for additional information concerning cash flow statements.<br/><br/>' +
                    'By clicking OK, a new set of GL account records to categorize cash flow statement records will be created and cash flow statement will be enabled in your Salesforce org.<br/><br/>' +
                    'Please click the Cancel button if you DO NOT wish to proceed.',
                callback: function (value) {
                    if (!value) {
                        $(checkbox).prop("checked", false);
                    }
                }
            });
        }

    };

    ASModule.enableAutoPostSourceDocuments = function (checkbox, isERPEnabled) {

        var fsRecords = ['Cash Receipts', 'Billings Cash Receipts', 'AP Disbursements', 'Amortization Entries'];
        var erpRecords = ['Sales Order Inventory Movements', 'Purchase Order Inventory Movements', 'Inbound Inventory Movements', 'Outbound Inventory Movements', 'Manufacturing Inventory Movements'];
        var header = 'Are you sure you want to {0} Auto-Post functionality?<br/><br/>';
        var body =
            'Auto-Post functionality controls the posting behavior of the following records: ' +
            (isERPEnabled ? fsRecords.join(', ') + ', ' + erpRecords.join(', ') + '.' : fsRecords.join(', ') + '.') + '<br/><br/>' +
            ' If Auto-Post is not enabled, then the Scheduled Post Job in the Automation Center must be set up in order for these records to post.<br/><br/>';
        var footer =
            'By clicking OK, this Auto-Post functionality is {0}. {1}<br/><br/>' +
            'Please click the Cancel button if you DO NOT wish to proceed.';

        if ($(checkbox).is(":checked")) {
            header = header.replace('{0}', 'enable');
            footer = footer.replace('{0}', 'enabled').replace('{1}', 'It can be disabled by deselecting the checkbox.');
            vex.dialog.confirm({
                message: header + body + footer,
                callback: function (value) {
                    if (!value) {
                        $(checkbox).prop("checked", false);
                    }
                }
            });
        }
        else {
            header = header.replace('{0}', 'disable');
            footer = footer.replace('{0}', 'disabled').replace('{1}', '');
            vex.dialog.confirm({
                message: header + body + footer,
                callback: function (value) {
                    if (!value) {
                        $(checkbox).prop("checked", false);
                    }
                }
            });
        }

    };

    ASModule.createTrialDataConfirm = function () {

        vex.dialog.buttons = {
            NO: {
                text: 'Cancel',
                type: 'button',
                className: 'vex-dialog-button-primary',
                click: function noClick() {
                    vex.close()
                }
            },
            YES: {
                text: 'OK',
                type: 'button',
                className: 'vex-dialog-button-secondary',
                click: function yesClick() {
                    this.value = true;
                    createTrialData();
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
            message: 'Are you sure you want to create trial data?<br/><br/>By clicking OK, a test set of Accounting Seed Financial Suite data will be created in your org.<br/><br/>Please click the Cancel button if you DO NOT wish to proceed.',
            callback: function (value) {
            }
        });
    };

    ASModule.clearErrorInputs = function () {
        $(".error").each(function () {
            $(this).val('')
        });
    };

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);