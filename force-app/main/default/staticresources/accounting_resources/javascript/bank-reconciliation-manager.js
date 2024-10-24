AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    var clearedTable;
    var unclearedTable;
    var currencyFormatter = ASModule.currencyFormatterProxy;
    var isLineLimitError = false;
    var errorMessage = "";
    var currencyIsoCode = ASModule.currencyIsoCode !== undefined ? ASModule.currencyIsoCode : 'USD';
    var pq = ASModule.packageQualifier;
    var needShowError = false;

    ASModule.setClearedDateSelected = function(obj) {
        var offset = obj.id.split(":")[1];
        var clearedDate = $('[id$=":' + offset + ':unclearedClearedDateInput"]');

        if (obj.checked) {
            var docDate = $(clearedDate.parent().siblings()[2]).text();
            clearedDate.val(clearedDate.val() === undefined || clearedDate.val() === "" ? docDate : clearedDate.val());
        }
        else {
            clearedDate.val("");
        }
    };

    ASModule.setCheckByClearedDate = function(currentObjectsList) {
        currentObjectsList.forEach(function(val) {
            if (val.clearedDate !== undefined && val.clearedDate !== "") {
                val.selected = true;
            }
        });
    };

    ASModule.setClearedDateUnselected = function(clearedDate) {
        var offset = clearedDate.id.split(":")[4];
        var checkBox = $('[id$=":' + offset + ':unclearedCheckbox1"]');

        if (checkBox.prop('checked') && clearedDate.val() === "") {
            checkBox.prop('checked', false);
        }
    };

    ASModule.setClearedDateUnselectedAll = function(checkboxId) {
        $('[id$=":' + checkboxId + '"]').each(function() {
            ASModule.setClearedDateSelected(this);
        });
    };

    ASModule.selectOrDeselectAll = function(allCheckboxId, checkboxId) {
        $('[id$=":' + checkboxId + '"]').add('.' + checkboxId).prop("checked", $('[id="' + allCheckboxId + '"]').add('.' + checkboxId).prop("checked"));
    };

    ASModule.setSelectAllUnchecked = function(allCheckboxId) {
        $('[id$=":' + allCheckboxId + '"]').prop("checked", false);
    };

    var processClear = function(selectedLines, bankRecId) {
        return new Promise(function(resolve, reject) {
            Visualforce.remoting.Manager.invokeAction(
              ASModule.clearAction,
              selectedLines,
              bankRecId,
              function(result, event){
                  event.status ? resolve(result) : reject(event);
              },
              {
                  timeout: 120000,
                  buffer: false
              }
            );
        });
    };

    var processUnclear = function(selectedLines) {
        return new Promise(function(resolve, reject) {
            Visualforce.remoting.Manager.invokeAction(
              ASModule.unclearAction,
              selectedLines,
              function(result, event){
                  event.status ? resolve(result) : reject(event);
              },
              {
                  timeout: 120000,
                  buffer: false
              }
            );
        });
    };

    var chunkArray = function (myArray, chunk_size){
        var index = 0;
        var arrayLength = myArray.length;
        var tempArray = [];
        for (index = 0; index < arrayLength; index += chunk_size) {
            var myChunk = myArray.slice(index, index+chunk_size);
            tempArray.push(myChunk);
        }
        return tempArray;
    }

    ASModule.clearBankReconciliations = function() {
        var bankRecId = $('#bankRecId').val();
        var selectedLines = [];
        var clearedLineCount = (clearedTable !== undefined ? clearedTable.data().length : 0);
        isLineLimitError = false;
        errorMessage = "";

        unclearedTable.rows().every(function(rowIdx, tableLoop, rowLoop) {
            var node = this.node();
            var data = this.data();
            var checkbox = $(node).find('.unclearedCheckbox');

            if ($(checkbox).prop('checked')) {
                data.selected = true;
                data.clearedDate = $(node).find('[id*="unclearedClearedDateInput"]').val();
                data.clearedDate = data.clearedDate ? data.clearedDate : 'Date field cannot be empty.';
                selectedLines.push(removeChildRelationship(removeUnusedData(data)));
            }
        });

        if (clearedLineCount + selectedLines.length > 4000) {
            AcctSeed.ASModule.pageLoad();
            isLineLimitError = true;
        }
        else if (selectedLines.length > 0) {
            var selectedChunks = [];
            var selectedLinesArray = chunkArray(selectedLines, 500);
            selectedLinesArray.forEach(function(element) {
                selectedChunks.push(element);
            });

            processClear(selectedChunks[0], bankRecId)
              .then(function() {
                  if (selectedChunks.length > 1) {
                      return processClear(selectedChunks[1], bankRecId);
                  } else {
                      return Promise.resolve();
                  }
              })
              .then(function(result) {
                  ASModule.pageLoad();
                  $('[id$=":unclearedSuccess"]').show();
              })
              .catch(function(exception) {
                  ASModule.pageLoad();
                  needShowError = true;
                  handleError(exception);
              });
        }
        else {
            ASModule.pageLoad();
        }
    };

    ASModule.unclearBankReconciliations = function() {
        $('[id$="thePanel"]').hide();
        var selectedLines = [];
        isLineLimitError = false;
        errorMessage = "";

        clearedTable.rows().every(function(rowIdx, tableLoop, rowLoop) {
            var node = this.node();
            var data = this.data();
            var checkbox = $(node).find('.clearedCheckbox');

            if ($(checkbox).prop('checked')) {
                data.selected = true;
                selectedLines.push(removeChildRelationship(removeUnusedData(data)));
            }
        });
        if (selectedLines.length > 0) {
            var selectedChunks = [];
            var selectedLinesArray = chunkArray(selectedLines, 500);
            selectedLinesArray.forEach(function(element) {
                selectedChunks.push(element);
            });

            processUnclear(selectedChunks[0])
              .then(function() {
                  if (selectedChunks.length > 1) {
                      return processUnclear(selectedChunks[1]);
                  } else {
                      return Promise.resolve();
                  }
              })
              .then(function() {
                  ASModule.pageLoad();
                  $('[id$=":clearedSuccess"]').show();
              })
              .catch(function(exception) {
                  handleError(exception);
              });
        }
        else {
            ASModule.pageLoad();
        }
    };

    ASModule.getClearedBankReconciliations = function() {
        var bankRecId = $('#bankRecId').val();
        Visualforce.remoting.Manager.invokeAction(
            ASModule.getClearedBankReconciliationAction,
            bankRecId,
            'All',
            currencyIsoCode,
            ASModule.bankRecLedgerId,
            handleResult, {
                escape: false,
                timeout: 120000
            }
        );

        function handleResult(result, event) {
            if (event.status) {
                if (result !== undefined && result.length > 0) {
                    formatClearedTable(result);
                    $('#clearLRDate2').html(clearedTable.column(1).data()[0]);
                    $('#clearMRDate2').html(clearedTable.column(1).data()[clearedTable.column(1).data().length - 1]);
                    $('[id$="lrcdlabel"]').show();
                    $('[id$="mrcdlabel"]').show();
                    $('[id$="noClearedRecords"]').hide();
                    $('[id$="unclearButton"]').show();
                }
                else {
                    $('[id$="noClearedRecords"]').show();
                    $('[id$="unclearButton"]').hide();
                    //since there are no any cleared lines
                    //we need clear the table on the DataTable plugin level
                    //to prevent wrong BR Ending Balance calculation
                    if (clearedTable !== undefined) {
                        clearedTable.clear();
                    }
                }

                ASModule.calculateDepositsAndDisbursements();
            }
            else {
                handleError(event);
            }
        }
    };

    var formatClearedTable = function(clearedBankRecs) {
        if (clearedTable !== undefined) {//to prevent init error
            clearedTable.clear();
        }

        clearedTable = $('#clearedTable').DataTable({
            "data": clearedBankRecs,
            "lengthMenu": [[10, 25, 50, 100, 500], [10, 25, 50, 100, 500]],
            "pageLength": 100,
            "columns": [{
                "title": "<input id=\"clearedCheckboxHeader\" type=\"checkbox\"/>",
                "data": "selected"
            }, {
                "title": "Bank Transaction Date",
                "data": "clearedDate"
            }, {
                "title": "Customer/Payee",
                "data": "entity"
            }, {
                "title": "Date",
                "data": "documentDate"
            }, {
                "title": "Amount",
                "data": "amount",
                "className": "dt-right"
            }, {
                "title": "Reference",
                "data": "reference"
            }, {
                "title": "Source",
                "data": "sourceObj"

            } ],
            "columnDefs": [{
                searchable: false,
                orderable: false,
                targets: 0,
                "render": function(data, type, full, meta) {
                    return '<input class="clearedCheckbox" onchange="AcctSeed.ASModule.checkSelectedClearedLimit()" type="checkbox"/>';
                }

            }, {
                targets: 4,
                "render": function(data, type, full, meta) {
                    if ( type === "sort" || type === 'type' ) {
                        return data;
                    }
                    else {
                        return currencyFormatter(data);
                    }
                }
            }, {
                targets: 6,
                "render": function(data, type, full, meta) {
                    return '<a target="_blank" href="'+ data.baseURL + '/' + data.sourceId + '">' + data.sourceType + '</a>';
                }
            }],
            "order": [
                [1, 'asc']
            ]
        });

        $('#clearedCheckboxHeader').on('change', function() {
            ASModule.selectOrDeselectAll(this.id, 'clearedCheckbox');
            ASModule.checkSelectedClearedLimit();
        });
    };

    ASModule.checkSelectedClearedLimit = function() {

        if (ASModule.checkedCount(clearedTable, '.clearedCheckbox') > 1000) {
            $('[id$="selectClearedLimitError"]').show();
            $('[id$=":unclearButton"]').hide();
        }
        else {
            $('[id$="selectClearedLimitError"]').hide();
            $('[id$=":unclearButton"]').show();
        }
    }

    ASModule.checkedCount = function(tableType, checkBoxClass) {
        var count = 0;
        tableType.rows().every(function(rowIdx, tableLoop, rowLoop) {
            var checkbox = $(this.node()).find(checkBoxClass);
            if ($(checkbox).prop('checked')) {
                count ++;
            }
        });
        return count;
    }

    ASModule.searchRecords = function() {
        var selectedUnclearedType = $('[id$="unclearedType"]').val();
        var startDate = $('[id$="startDate"]').is("input") ? $('[id$="startDate"]').val() : $('[id$="startDate"]').html();
        var endDate = $('[id$="endDate"]').is("input") ? $('[id$="endDate"]').val() : $('[id$="endDate"]').html();
        var bankAccountId = $('#bankAccountId').val();
        var glavVar1 = $('[id$="glavVar1"]').val() !== undefined ? $('[id$="glavVar1"]').val() : "";
        var glavVar2 = $('[id$="glavVar2"]').val() !== undefined ? $('[id$="glavVar2"]').val() : "";
        var glavVar3 = $('[id$="glavVar3"]').val() !== undefined ? $('[id$="glavVar3"]').val() : "";
        var glavVar4 = $('[id$="glavVar4"]').val() !== undefined ? $('[id$="glavVar4"]').val() : "";
        errorMessage = "";
        isLineLimitError = false;

        $('[id$="loadingImage"]').show();

        Visualforce.remoting.Manager.invokeAction(
            ASModule.searchRecordsAction,
            selectedUnclearedType,
            startDate,
            endDate,
            bankAccountId,
            glavVar1,
            glavVar2,
            glavVar3,
            glavVar4,
            4000,
            currencyIsoCode,
            ASModule.bankRecLedgerId,
            handleResult, {
                escape: false,
                timeout: 120000
            }
        );

        function handleResult(result, event) {
            if (event.status) {
                if (result !== undefined && result.length > 0) {
                    formatUnclearedTable(result);
                    needShowError ? $('[id$="errorPanel"]').show() : $('[id$="errorPanel"]').hide();
                    $('[id$=":clearButton"]').show();
                    $('[id$="overSizeUncleared"]').hide();
                    needShowError = false;
                }
                else {
                    if (unclearedTable !== undefined) {//when second search attempt return no rows
                        unclearedTable.clear();
                    }
                }
                if (result !== undefined && result.length >= 4000) {
                    $('[id$="overSizeUncleared"]').show();
                }
            }
            else {
                handleError(event);
            }

            ASModule.getClearedBankReconciliations();
        }
    };

    var formatUnclearedTable = function(unclearedBankRecs) {
        var clearedDateCount = 0;
        if (unclearedTable !== undefined) {//to prevent init error
            unclearedTable.clear();
        }
        ASModule.setCheckByClearedDate(unclearedBankRecs);
        unclearedTable = $('#unclearedTable').DataTable({
            "data": unclearedBankRecs,
            "lengthMenu": [[10, 25, 50, 100, 500], [10, 25, 50, 100, 500]],
            "pageLength": 100,
            "columns": [{
                "title": "<input id=\"unclearedCheckboxHeader\" type=\"checkbox\"/>",
                "data": "selected"
            }, {
                "title": "Bank Transaction Date",
                "data": "clearedDate"
            }, {
                "title": "Customer/Payee",
                "data": "entity"
            }, {
                "title": "Date",
                "data": "documentDate"
            }, {
                "title": "Amount",
                "data": "amount",
                "className": "dt-right"
            }, {
                "title": "Reference",
                "data": "reference"
            }, {
                "title": "Source",
                "data": "sourceObj"
            }, ],
            "columnDefs": [{
                searchable: false,
                orderable: false,
                targets: 0,
                "render": function(data, type, full, meta) {
                    var theId = ':' + clearedDateCount + ':unclearedCheckbox';
                    return '<input class="unclearedCheckbox" id="' + theId + '" onchange="AcctSeed.ASModule.setClearedDateSelected(this); AcctSeed.ASModule.checkSelectedUnclearedLimit()" type="checkbox" ' + (data ? "checked" : "") + '/>';
                }

            }, {
                targets: 1,
                orderable: false,
                "render": function(data, type, full, meta) {
                    var date = data ? data : '';
                    var fieldId = ':' + (clearedDateCount++) + ':unclearedClearedDateInput';
                    return '<input size="10" id="' + fieldId + '" onfocus="DatePicker.pickDate(false, \'' + fieldId + '\', false);" value="' + date + '"/>';
                }

            }, {
                targets: 4,
                "render": function(data, type, full, meta) {
                    if ( type === "sort" || type === 'type' ) {
                        return data;
                    }
                    else {
                        return currencyFormatter(data);
                    }
                }
            }, {
                targets: 6,
                "render": function(data, type, full, meta) {
                    return '<a target="_blank" href="' + data.baseURL + '/' + data.sourceId + '">' + data.sourceType + '</a>';
                }
            }],
            "order": [
                [3, 'asc']
            ]
        });

        $('#unclearedCheckboxHeader').on('change', function() {
            ASModule.selectOrDeselectAll(this.id, 'unclearedCheckbox');
            ASModule.checkSelectedUnclearedLimit();
            $('[id$="unclearedCheckbox"]').each(function() {
                AcctSeed.ASModule.setClearedDateSelected(this);
            });
        });
    };

    ASModule.checkSelectedUnclearedLimit = function() {
        if (ASModule.checkedCount(unclearedTable, '.unclearedCheckbox') > 1000) {
            $('[id$="selectUnclearedLimitError"]').show();
            $('[id$=":clearButton"]').hide();
        }
        else {
            $('[id$="selectUnclearedLimitError"]').hide();
            $('[id$=":clearButton"]').show();
        }
    }

    ASModule.calculateDepositsAndDisbursements = function() {
        var bankRecId = $('#bankRecId').val();

        Visualforce.remoting.Manager.invokeAction(
            ASModule.calculateDepositsAndDisbursementsAction,
            bankRecId,
            handleResult, {
                timeout: 120000
            }
        );

        function handleResult(result, event) {
            if (event.status) {
                $('[id$="begBalanceAmount"]').text(currencyFormatter($('[id$="begBalanceAmount"]').text()));
                $('[id$="clearedDepositAmount"]').text(currencyFormatter(result[ASModule.packageQualifier + "Cleared_Deposits__c"]));
                $('[id$="clearedDisbursmentAmount"]').text(currencyFormatter(result[ASModule.packageQualifier + "Cleared_Disbursements__c"]));
                $('[id$="calBegBalanceAmount"]').text(currencyFormatter(result[ASModule.packageQualifier + "Beginning_Balance__c"]));
                $('[id$="unclearedAmount"]').text(currencyFormatter(result[ASModule.packageQualifier + "Ending_Balance__c"]));
                $('[id$="endBalanceAmount"]').text(currencyFormatter($('[id$="endBalanceAmount"]').text()));

                $('[id$="begBalanceAmount"]').show();
                $('[id$="clearedDepositAmount"]').show();
                $('[id$="clearedDisbursmentAmount"]').show();
                $('[id$="calBegBalanceAmount"]').show();
                $('[id$="unclearedAmount"]').show();
                $('[id$="endBalanceAmount"]').show();
            }
            else {
                handleError(event);
            }

            $('[id$="loadingImage"]').hide();
            $('[id$="thePanel"]').show();
            ASModule.showMessages();
        }

    };

    var handleError = function(event) {
        if (event.type === 'exception') {
            displayErrorPanel(event);
        }
        else {
            displayErrorPanel(event);
        }
        $('[id$="loadingImage"]').hide();
        $('[id$="thePanel"]').hide();
    };

    var displayErrorPanel = function(event) {
        $('[id$="errorPanel"]').show();
        $('[id$="errorPanel"]').find('h4').html('Error: ' + event.message);
    };

    ASModule.showMessages = function(action) {
        if (unclearedTable === undefined || unclearedTable.column(1).data().length === 0) {
            $('[id$="noUnclearedRecords"]').show();
            $('[id$=":clearButton"]').hide();
        }
        else {
            $('[id$="noUnclearedRecords"]').hide();
        }

        if (clearedTable === undefined || clearedTable.column(1).data().length === 0) {
            $('[id$="noClearedRecords"]').show();
            $('[id$="unclearButton"]').hide();
        }
        else {
            $('[id$="noClearedRecords"]').hide();
            $('[id$="unclearButton"]').show();
        }

        if (isLineLimitError) {
            $('[id$="lineLimitError"]').show();
        }
        else {
            $('[id$="lineLimitError"]').hide();
        }

        if (errorMessage !== "") {
            $('[id$="errorPanel"]').show();
            $('[id$="errorPanel"]').find('h4').html('Error: ' + errorMessage);
        }
    };

    var removeUnusedData = function(data) {
        var fieldSet = ['Reference__c', 'Ledger_Amount__c', 'Amount__c', 'Account__c', 'Journal_Entry__c', 'Payee__c', 'Deposit_Reference__c', 'Name', 'Payment_Reference__c'];
        fieldSet.forEach(function (s) {
            if (data.obj.hasOwnProperty(pq + s)) {
                delete data.obj[pq + s];
            }
        });
        data.cr = {};
        data.sourceObj = {};
        data.reference = '';
        data.documentDate = '';
        data.entity = '';
        return data;
    };

    var removeChildRelationship = function(data) {
        if (data.obj.hasOwnProperty('Cash_Receipts__r')) {
            delete data.obj.Cash_Receipts__r;
        }
        else if (data.obj.hasOwnProperty('AcctSeed__Cash_Receipts__r')) {
            delete data.obj.AcctSeed__Cash_Receipts__r;
        }
        if (data.obj.hasOwnProperty('Account__r')) {
            delete data.obj.Account__r;
        }
        else if (data.obj.hasOwnProperty('AcctSeed__Account__r')) {
            delete data.obj.AcctSeed__Account__r;
        }

        return data;
    };

    ASModule.pageLoad = function() {
        ASModule.searchRecords();
    };

    $(function() {
        $.fn.dataTable.moment("DD/MM/YYYY", ASModule.defaultLocale);
        ASModule.pageLoad();
    });

    return ASModule;
})(window, document, $j, AcctSeed.ASModule);