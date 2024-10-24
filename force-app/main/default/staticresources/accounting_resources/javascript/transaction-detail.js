AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    var theTable;
    var numberFormatter = ASModule.numberFormatter;

    var formatTable = function(dataSource) {
        theTable = $('[id$="theTable"]').DataTable({
            "data": dataSource,
            "columns": [{
                "title": "Id",
                "data": "id"
            }, {
                "title": ASModule.objectMetadata.Transaction__c.fields.Date__c.label,
                "data": "transactionDate"
            }, {
                "title": ASModule.objectMetadata.Transaction__c.fields.Account__c.label,
                "data": "account"
            }, {
                "title": "Source",
                "data": "source"
            }, {
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
                targets: [0, 2, 4, 5, 6, 7, 8, 9, 10],
                "render": function(data, type, full, meta) {
                    var cellContent =
                        (data.id !== '')
                            ? '<a href="/' + data.id + '" target="_blank">' + data.name + '</a>'
                            : '<span style="color:red">' + data.name + '</span>';
                    return (data.isAccessible) ? cellContent : '';
                }
            },{
                targets: 3,
                "render": function(data, type, full, meta) {
                    var cellContent =
                        (data.id !== '')
                            ? '<a href="/' + data.id + '" target="_blank">' + data.name + '</a>'
                            : '<span style="color:red">' + data.name + '</span>';
                    return (data.isAccessible) ? cellContent : 'NULL';
                },

            },{
                targets: 11,
                "render": function(data, type, full, meta) {
                    if (type === "display") {//use formatted data for UI
                        return numberFormatter(data, 2, true);
                    }
                    return data;//use raw data for sorting
                },

            },{
                className: "dt-right", "targets": [11]
            }],
            "order": [
                [1, 'asc']
            ],
            "lengthMenu": [10, 25, 50],
            "pageLength": 10,
            "autoWidth": false
        });
    };

    ASModule.getTransactions = function() {
        var glAccountId = $('[id$="glAccountId"]').val();
        var acctPeriodId = $('[id$="acctPeriodId"]').val();
        var ledgerId = $('[id$="ledgerId"]').val();
        var glavVariable1 = $('[id$="glavVariable1"]').val() !== undefined ? $('[id$="glavVariable1"]').val() : "";
        var glavVariable2 = $('[id$="glavVariable2"]').val() !== undefined ? $('[id$="glavVariable2"]').val() : "";
        var glavVariable3 = $('[id$="glavVariable3"]').val() !== undefined ? $('[id$="glavVariable3"]').val() : "";
        var glavVariable4 = $('[id$="glavVariable4"]').val() !== undefined ? $('[id$="glavVariable4"]').val() : "";
        var isERPEnabled = $('[id$="isERPEnabled"]').val();

        Visualforce.remoting.Manager.invokeAction(
            ASModule.getTransactionsAction,
            glAccountId,
            acctPeriodId,
            ledgerId,
            glavVariable1,
            glavVariable2,
            glavVariable3,
            glavVariable4,
            isERPEnabled,
            handleResult, {
                escape: false
            }
        );

        function handleResult(result, event) {
            if (event.status) {
                formatTable(result);
            }
            else if (event.type === 'exception') {

            }
            else {

            }
        }
    };

    var setFormatTransactionAmount = function () {
        $('[id$=":transactionAmount"]').text(numberFormatter($('[id$=":transactionAmount"]').text(), 2, true));
    }

    $(document).ready(function() {
        ASModule.getTransactions();
        setFormatTransactionAmount();
        $('[id$="thePanel"]').show();
    });

})(window, document, $j, AcctSeed.ASModule);