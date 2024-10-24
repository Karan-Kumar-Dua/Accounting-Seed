AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    var transactionTable;
    var numberFormatter = ASModule.numberFormatter;

    ASModule.disableButtons = function(tabId, label, showSpinner) {
        $('[id*="' + tabId + '"] .pbButton > .btn,[id*="' + tabId + '"] .pbButtonb > .btn').prop('disabled', true).val(label).toggleClass('btnDisabled');
        $('[id$="errorPanel"]').hide();

        if (showSpinner === true) {
            $('#spinner').show();
        }
    };

    ASModule.enableButtons = function(tabId, label) {
        $('[id*="' + tabId + '"] .pbButton > .btn,[id*="' + tabId + '"] .pbButtonb > .btn').prop('disabled', false).val(label).removeClass('btnDisabled');
    };

    ASModule.setSubType1Checkbox = function(subTypeId_1, subTypeId_2) {
        var subType1 = $('[id$="' + subTypeId_1 + '"]');
        var subType2 = $('[id$="' + subTypeId_2 + '"]');

        if (!subType1.prop('checked')) {
            subType2.prop('checked', false);
        }
    };

    ASModule.setSubType2Checkbox = function(subTypeId_1, subTypeId_2) {
        var subType1 = $('[id$="' + subTypeId_1 + '"]');
        var subType2 = $('[id$="' + subTypeId_2 + '"]');

        if (subType2.prop('checked')) {
            subType1.prop('checked', true);
        }
    };

    ASModule.destroyOldReport = function() {
        ASModule.calculateStatistics({openingBalance: 0, currentBalance: 0, reportAmount: 0, recordCount: 0});
        if (transactionTable !== undefined && $.fn.DataTable.isDataTable('[id$="transactionTable"]')) {
            transactionTable.destroy();
            $('[id$="transactionTable"]').html('');
        }
    };

    ASModule.runLedgerInquiryReport = function(request) {
        if (!request) {
            ledgerInquiryRefreshAction();
            $('[id$="spinner"]').hide();
            return;
        }

        Visualforce.remoting.Manager.invokeAction(
            ASModule.getTransactionsByLedgerInquiryRequest,
            request,
            handleResult, {
                escape: false,
                timeout: 120000
            }
        );

        function handleResult(result, event) {
            if (event.status) {
                if (result !== undefined && result.lines.length > 0) {
                    formatTransactionTable(result);
                    ASModule.calculateStatistics(result);
                    if (result.limitedOutput) {
                        handleWarning('The first 5000 records of your search are displayed below. Please refine your search criteria to reduce the number of records retrieved.');
                    }
                }
                else {
                    handleError('No transactions exist for selected criteria.');
                }
            }
            else {
                handleError(event.message);
            }

            ledgerInquiryRefreshAction();
            $('[id$="spinner"]').hide();
        };
    };

    var formatTransactionTable = function(dataSource) {
        transactionTable = $('[id$="transactionTable"]').DataTable({
            "data": dataSource.lines,
            "columns": [{
                "title": "Transaction ID",
                "data": "id"
            }, {
                "title": ASModule.objectMetadata.Transaction__c.fields.Date__c.label,
                "data": "transactionDate"
            }, {
               "title": ASModule.objectMetadata.Transaction__c.fields.GL_Account__c.label,
               "data": "glAccount"
            }, {
                "title": ASModule.objectMetadata.Transaction__c.fields.Account__c.label,
                "data": "account"
            }, {
                "title": "Source",
                "data": "source"
            }, {
                "title": ASModule.objectMetadata.Transaction__c.fields.Accounting_Period__c.label,
                "data": "accountingPeriod"
            },{
                "title": ASModule.objectMetadata.Transaction__c.fields.Project__c.label,
                "data": "project"
            }, {
                "title": ASModule.objectMetadata.Transaction__c.fields.Project_Task__c.label,
                "data": "projectTask"
            }, {
                "title": ASModule.objectMetadata.Transaction__c.fields.Product__c.label,
                "data": "product"
            }, {
                "title": ASModule.objectMetadata.Transaction__c.fields.GL_Account_Variable_1__c.label,
                "data": "glav1"
            }, {
                "title": ASModule.objectMetadata.Transaction__c.fields.GL_Account_Variable_2__c.label,
                "data": "glav2"
            }, {
                "title": ASModule.objectMetadata.Transaction__c.fields.GL_Account_Variable_3__c.label,
                "data": "glav3"
            }, {
                "title": ASModule.objectMetadata.Transaction__c.fields.GL_Account_Variable_4__c.label,
                "data": "glav4"
            }, {
                "title": ASModule.objectMetadata.Transaction__c.fields.Amount__c.label,
                "data": "amount"
            }],
            "columnDefs": [{
                targets: [0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
                "render": function(data, type, full, meta) {
                    var cellContent =
                        (data.id !== '')
                            ? '<a href="/' + data.id + '" target="_blank">' + data.name + '</a>'
                            : '<span style="color:red">' + data.name + '</span>';
                    return (data.isAccessible) ? cellContent : '';
                }
            }, {
                targets: 13,
                "render": function(data, type, full, meta) {
                    if (type === "display") {//use formatted data for UI
                        return numberFormatter(data, 2, true);
                    }
                    return data;//use raw data for sorting
                }
            }, {
                 className: "dt-right", "targets": [12]
            }],
            "order": [
                [1, 'asc']
            ],
            "lengthMenu": [50, 100, 200],
            "pageLength": 50,
            "autoWidth": false
        });
    };

    ASModule.calculateStatistics = function(dataSource) {
        $('[id$="openingBalance"]').text(numberFormatter(dataSource.openingBalance, 2, true));
        $('[id$="currentBalance"]').text(numberFormatter(dataSource.currentBalance, 2, true));
        $('[id$="reportAmount"]').text(numberFormatter(dataSource.reportAmount, 2, true));
        $('[id$="recordCount"]').text(dataSource.recordCount);
    };

    var handleError = function(errorMessage) {
        displayErrorPanel(errorMessage);
        ASModule.calculateStatistics({openingBalance: 0, currentBalance: 0, reportAmount: 0, recordCount: 0});
    };

    var handleWarning = function(errorMessage) {
        displayErrorPanel(errorMessage);
    };

    var displayErrorPanel = function(errorMessage) {
        $('[id$="errorPanel"]').show();
        $('[id$="errorPanel"]').find('h4').html(errorMessage);
    };

    var handlePolling = function() {
        var needRefresh;
        $('[id$="statusColumn"]').each(function() {
            if(this.innerText != 'Completed') {
                needRefresh = true;
            };
        });
        if (needRefresh) {
            refreshComponents();
        }
    };

    ASModule.pageLoad = function() {
        ASModule.calculateStatistics({openingBalance: 0, currentBalance: 0, reportAmount: 0, recordCount: 0});
    };

    $(document).ready(function($) {
        ASModule.pageLoad();
        window.setInterval(handlePolling, 5000);
    });

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);