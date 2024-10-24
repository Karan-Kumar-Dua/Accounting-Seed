AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    var currencyFormatterProxy = ASModule.currencyFormatterProxy;
    var currencyIsoCode = ASModule.currencyIsoCode !== undefined ? ASModule.currencyIsoCode : 'USD';
    var associatedTable;
    var unassociatedTable;
    var totalAmountTempStorage;
    var totalLedgerAmountTempStorage;
    var needShowError = false;
    var pq = ASModule.packageQualifier;
    var isMultiCurrencyEnabled =
        ASModule.isMultiCurrencyEnabled !== undefined
            ? ((ASModule.isMultiCurrencyEnabled == 'true') ? true : false)
            : false;

    ASModule.selectOrDeselectAll = function(allCheckboxId, checkboxClass) {
        $('.' + checkboxClass).each(function() {
            $(this).prop("checked", $('[id="' + allCheckboxId+ '"]').prop("checked"));
        });
    };

    ASModule.setSelectAllUnchecked = function(allCheckboxId) {
        $('[id="' + allCheckboxId + '"]').prop("checked", false);
    };

    var formatAssociatedTable = function(dataSource) {
        if (associatedTable !== undefined) {//if DataTable was initiated before
            associatedTable.clear();
        }
        associatedTable = $('#associatedTable').DataTable({
            "data": dataSource,
            "lengthMenu": [[10, 25, 50, 100, 500], [10, 25, 50, 100, 500]],
            "pageLength": 100,
            "columns": [{
                "title": "<input id=\"associatedCheckboxHeader\" type=\"checkbox\"/>",
                "data": "selected"
            }, {
                "title": "Name",
                "data": "sourceObj"
            }, {
                "title": "Customer Name",
                "data": "customerName"
            }, {
                "title": "Record Date",
                "data": "objDate"
            }, {
                "title": "Amount",
                "data": "money"
            }, {
                "title": "Ledger Amount",
                "data": "money"
            }, {
                "title": "Reference",
                "data": "reference"
            }, {
                "title": "Source",
                "data": "sourceObj"
            }],
            "columnDefs": [{
                searchable: false,
                orderable: false,
                targets: 0,
                "render": function(data, type, full, meta) {
                    return '<input class="associatedCheckbox" onchange="AcctSeed.ASModule.checkSelectedAssociateLimit()" type="checkbox"/>';
                }

            }, {
                targets: 1,
                "render": function(data, type, full, meta) {
                    return '<a target="_blank" href="'+ data.baseURL + '/' + data.sourceId + '">' + data.sourceName + '</a>';
                }
            }, {
                targets: 4,
                "createdCell": function(td, cellData, rowData, row, col) {
                    if ( cellData.recordAmount < 0 ) {
                        $(td).addClass('negativeAmount');
                    }
                },
                "render": function(data, type, full, meta) {
                    if ( type === "sort" || type === 'type' ) {
                        return data.recordAmount;
                    }
                    else {
                        return currencyFormatterProxy(data.recordAmount, 2, false, data.recordCurrency);
                    }
                },
                className: 'align-right'
            }, {
                targets: 5,
                visible: isMultiCurrencyEnabled,
                "createdCell": function(td, cellData, rowData, row, col) {
                    if ( cellData.ledgerAmount < 0 ) {
                        $(td).addClass('negativeAmount');
                    }
                },
                "render": function(data, type, full, meta) {
                    if ( type === "sort" || type === 'type' ) {
                        return data.ledgerAmount;
                    }
                    else {
                        return currencyFormatterProxy(data.ledgerAmount, 2, false, data.ledgerCurrency);
                    }
                },
                className: 'align-right'
            }, {
                orderable: false,
                targets: 6
            }, {
                targets: 7,
                "render": function(data, type, full, meta) {
                    return '<a target="_blank" href="' + data.baseURL + '/' + data.sourceId + '">' + data.sourceType + '</a>';
                }
            }],
            "order": [
                [3, 'asc']
            ]
        });

        $('#associatedCheckboxHeader').on('change', function() {
            ASModule.selectOrDeselectAll(this.id, 'associatedCheckbox');
            ASModule.checkSelectedAssociateLimit();
        });

        $('.associatedCheckbox').each(function() {
            $(this).on('change', function() {
                ASModule.setSelectAllUnchecked('associatedCheckboxHeader');
            });
        });

    };

    var formatUnassociatedTable = function(dataSource) {
        if (unassociatedTable !== undefined) {//if DataTable was initiated before
            unassociatedTable.clear();
        }
        unassociatedTable = $('#unassociatedTable').DataTable({
            "data": dataSource,
            "lengthMenu": [[10, 25, 50, 100, 500], [10, 25, 50, 100, 500]],
            "pageLength": 100,
            "columns": [{
                "title": "<input id=\"unassociatedCheckboxHeader\" type=\"checkbox\"/>",
                "data": "selected"
            }, {
                "title": "Name",
                "data": "sourceObj"
            }, {
                "title": "Customer Name",
                "data": "customerName"
            }, {
                "title": "Record Date",
                "data": "objDate"
            }, {
                "title": "Amount",
                "data": "money"
            }, {
                "title": "Ledger Amount",
                "data": "money"
            }, {
                "title": "Reference",
                "data": "reference"
            }, {
                "title": "Source",
                "data": "sourceObj"
            }],
            "columnDefs": [{
                searchable: false,
                orderable: false,
                targets: 0,
                "render": function(data, type, full, meta) {
                    return '<input class="unassociatedCheckbox" onchange="AcctSeed.ASModule.checkSelectedUnassociateLimit()" type="checkbox"/>';
                }

            }, {
                targets: 1,
                "render": function(data, type, full, meta) {
                    return '<a target="_blank" href="' + data.baseURL + '/' + data.sourceId + '">' + data.sourceName + '</a>';
                }
            }, {
                targets: 4,
                "createdCell": function(td, cellData, rowData, row, col) {
                    if ( cellData.recordAmount < 0 ) {
                        $(td).addClass('negativeAmount');
                    }
                },
                "render": function(data, type, full, meta) {
                    if ( type === "sort" || type === 'type' ) {
                        return data.recordAmount;
                    }
                    else {
                        return currencyFormatterProxy(data.recordAmount, 2, false, data.recordCurrency);
                    }
                },
                className: 'align-right'
            }, {
                targets: 5,
                visible: isMultiCurrencyEnabled,
                "createdCell": function(td, cellData, rowData, row, col) {
                    if ( cellData.ledgerAmount < 0 ) {
                        $(td).addClass('negativeAmount');
                    }
                },
                "render": function(data, type, full, meta) {
                    if ( type === "sort" || type === 'type' ) {
                        return data.ledgerAmount;
                    }
                    else {
                        return currencyFormatterProxy(data.ledgerAmount, 2, false, data.ledgerCurrency);
                    }
                },
                className: 'align-right'
            }, {
                targets: 6,
                orderable: false,
                visible: true
            }, {
                targets: 7,
                "render": function(data, type, full, meta) {
                    return '<a target="_blank" href="' + data.baseURL + '/' + data.sourceId + '">' + data.sourceType + '</a>';
                }
            }],
            "order": [
                [3, 'asc']
            ]
        });

        $('#unassociatedCheckboxHeader').on('change', function() {
            ASModule.selectOrDeselectAll(this.id, 'unassociatedCheckbox');
            ASModule.checkSelectedUnassociateLimit();
        });

        $('.unassociatedCheckbox').each(function() {
            $(this).on('change', function() {
                ASModule.setSelectAllUnchecked('unassociatedCheckboxHeader');
            });
        });

    };

    ASModule.getAssociatedRecords = function() {
        Visualforce.remoting.Manager.invokeAction(
            ASModule.getAssociatedRecordsAction,
            ASModule.bankDepositId,
            currencyIsoCode,
            ASModule.bankLedgerId,
            handleResult, {
                escape: false,
                timeout: 120000
            }
        );

        function handleResult(result, event) {
            if (event.status) {
                if (result !== undefined && result.length > 0) {//build table on the page initial load
                    formatAssociatedTable(result);
                    $('#associatedMRDate').html(associatedTable.column(3).data()[0]);
                    $('#associatedLRDate').html(associatedTable.column(3).data()[associatedTable.column(3).data().length - 1]);
                    $('[id$="leastRecentRecordDateLabel"]').show();
                    $('[id$="mostRecentRecordDateLabel"]').show();
                    $('[id$="zeroAssociatedResults"]').hide();
                    $('[id$=":unAssociateButton"]').show();
                }
                else {//if we don't have records to display
                    $('[id$="leastRecentRecordDateLabel"]').hide();
                    $('#associatedLRDate').html('');
                    $('[id$="mostRecentRecordDateLabel"]').hide();
                    $('#associatedMRDate').html('');
                    $('[id$="zeroAssociatedResults"]').show();
                    $('[id$=":unAssociateButton"]').hide();
                }
            }
            else if (event.type === 'exception') {
                $('[id$="errorPanel"]').show();
                $('[id$="errorPanel"]').find('h4').html('Error: ' + event.message);
                $('[id$="dataTablePanel"]').hide();
            }
            else {
                $('[id$="errorPanel"]').show();
                $('[id$="errorPanel"]').find('h4').html('Error: ' + event.message);
                $('[id$="dataTablePanel"]').hide();
            }
        }
        
    };

    ASModule.getUnassociatedRecords = function() {

        ASModule.showOrHideDataPanel(false);
        var selectedUnassociatedType = $('[id$="unassociatedType"]').val();
        var startDate = $('[id$="startDate"]').val();
        var endDate = $('[id$="endDate"]').val();
        var glVariable1  = $('[id$="glavVar1"]').val() !== undefined ? $('[id$="glavVar1"]').val() : "";
        var glVariable2  = $('[id$="glavVar2"]').val() !== undefined ? $('[id$="glavVar2"]').val() : "";
        var glVariable3  = $('[id$="glavVar3"]').val() !== undefined ? $('[id$="glavVar3"]').val() : "";
        var glVariable4  = $('[id$="glavVar4"]').val() !== undefined ? $('[id$="glavVar4"]').val() : "";

        Visualforce.remoting.Manager.invokeAction(
            ASModule.getUnassociatedRecordsAction,
            selectedUnassociatedType,
            startDate,
            endDate,
            ASModule.bankAccountId,
            glVariable1,
            glVariable2,
            glVariable3,
            glVariable4,
            4000,
            currencyIsoCode,
            ASModule.bankLedgerId,
            handleResult, {
                escape: false,
                timeout: 120000
            }
        );

        function handleResult(result, event) {
            if (event.status) {

                if (result !== undefined && result.length > 0) {//build table on the page initial load
                    formatUnassociatedTable(result);
                    needShowError ? $('[id$="errorPanel"]').show() : $('[id$="errorPanel"]').hide();
                    $('[id$="zeroSearchResultMessage"]').hide();
                    $('[id$="associateButton"]').show();
                    needShowError = false;
                }
                else {//if we don't have records to display
                    $('[id$="zeroSearchResultMessage"]').show();
                    $('[id$="associateButton"]').hide();
                }

                if (result !== undefined && result.length >= 4000) {
                    $('[id$="lineLimitError"]').show();
                }
            }
            else if (event.type === 'exception') {
                $('[id$="errorPanel"]').show();
                $('[id$="errorPanel"]').find('h4').html('Error: ' + event.message);
                $('[id$="dataTablePanel"]').hide();
            }
            else {
                $('[id$="errorPanel"]').show();
                $('[id$="errorPanel"]').find('h4').html('Error: ' + event.message);
                $('[id$="dataTablePanel"]').hide();
            }
            ASModule.showOrHideDataPanel(true);
        }
    };

    ASModule.checkSelectedUnassociateLimit = function() {
        if (checkedCount(unassociatedTable, '.unassociatedCheckbox') > 1000) {
            $('[id$="selectUnassociatedLimitError"]').show();
            $('[id$=":associateButton"]').hide();
        }
        else {
            $('[id$="selectUnassociatedLimitError"]').hide();
            $('[id$=":associateButton"]').show();
        }
    };

    var processAssociate = function(selectedLines, associate) {
        return new Promise(function(resolve, reject) {
            Visualforce.remoting.Manager.invokeAction(
              ASModule.processAssociationAction,
              selectedLines,
              ASModule.bankDepositId,
              associate,
              function(result, event) {
                  event.status ? resolve(result) : reject(event);
              },
              {
                  timeout: 120000,
                  buffer: false
              }
            );
        });
    };

    var getAssociateTotal = function() {
        return new Promise(function(resolve, reject) {
            Visualforce.remoting.Manager.invokeAction(
              ASModule.getTotalAssociation,
              ASModule.bankDepositId,
              function(result, event) {
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
            var myChunk = myArray.slice(index, index + chunk_size);
            tempArray.push(myChunk);
        }
        return tempArray;
    }

    ASModule.associateSelectedLines = function() {
        var selectedLines = [];
        var associatedLineCount = (associatedTable !== undefined ? associatedTable.data().length : 0);

        unassociatedTable.rows().every(function(rowIdx, tableLoop, rowLoop) {
            var data = this.data();

            if ($($(this.node()).find('.unassociatedCheckbox')).prop('checked')) {
                data.selected = true;
                selectedLines.push(removeUnusedData(data));
            }
        });

        if (associatedLineCount + selectedLines.length > 4000) {
            $('[id$="overSizeUnassociated"]').show();
            setTotalAmountFromTempStorage();
            loadRecords();
        }
        else if (selectedLines.length > 0) {
            var selectedChunks = [];
            var selectedLinesArray = chunkArray(selectedLines, 500);
            selectedLinesArray.forEach(function(element) {
                selectedChunks.push(element);
            });

            processAssociate(selectedChunks[0], true)
              .then(function() {
                  if (selectedChunks.length > 1) {
                      return processAssociate(selectedChunks[1], true);
                  } else {
                      return Promise.resolve();
                  }
              })
              .then(function() {return getAssociateTotal()})
              .then(function(result) {
                  loadRecords();
                  setTotalAmountFromDB(result);
                  $('[id$=":associationCompleteMessage"]').show();
              })
              .catch(function(exception) {
                  needShowError = true;
                  loadRecords();
                  $('[id$="errorPanel"]').show();
                  $('[id$="errorPanel"]').find('h4').html('Error: ' + exception.message);
              });
        }
        else {
            setTotalAmountFromTempStorage();
            loadRecords();
        }
    };

    var setTotalAmountFromDB = function(result) {
        totalAmountTempStorage = currencyFormatterProxy(result.recordAmount, 2, false);
        totalLedgerAmountTempStorage = currencyFormatterProxy(result.ledgerAmount, 2, false, result.ledgerCurrency);
        $('[id$="totalAmount"]').text(totalAmountTempStorage);
        $('[id$="totalLedgerAmount"]').text(totalLedgerAmountTempStorage);
        setColorIfNegative($('[id$="totalAmount"]'));
        setColorIfNegative($('[id$="totalLedgerAmount"]'));
    };

    var setColorIfNegative = function(amountFieldElement) {
        var amountValue = ASModule.numberParserByLocale($(amountFieldElement).text());
        if (amountValue < 0) {
            $(amountFieldElement).addClass('negativeAmount');
        }
        else {
            $(amountFieldElement).removeClass('negativeAmount');
        }
    };

    var setTotalAmountFromTempStorage = function() {
        $('[id$="totalAmount"]').text(totalAmountTempStorage);
        $('[id$="totalLedgerAmount"]').text(totalLedgerAmountTempStorage);
    };

    ASModule.disableButtonsSpecialForBankManagerPage = function(label) {
        $('[id$="thePanel"] .pbButton > .btn, [id$="thePanel"] .pbButtonb > .btn').toggleClass('btnDisabled').prop('disabled', true).val(label);
    };

    ASModule.checkSelectedAssociateLimit = function() {
        if (checkedCount(associatedTable, '.associatedCheckbox') > 1000) {
            $('[id$="selectAssociatedLimitError"]').show();
            $('[id$=":unAssociateButton"]').hide();
        }
        else {
            $('[id$="selectAssociatedLimitError"]').hide();
            $('[id$=":unAssociateButton"]').show();
        }
    };

    ASModule.unassociateSelectedLines = function() {
        var selectedLines = [];
        associatedTable.rows().every(function(rowIdx, tableLoop, rowLoop) {
            var data = this.data();

            if ($($(this.node()).find('.associatedCheckbox')).prop('checked')) {
                data.selected = true;
                selectedLines.push(removeUnusedData(data));
            }
        });

        if (selectedLines.length > 0) {
            var selectedChunks = [];
            var selectedLinesArray = chunkArray(selectedLines, 500);
            selectedLinesArray.forEach(function(element) {
                selectedChunks.push(element);
            });

            processAssociate(selectedChunks[0], false)
              .then(function() {
                  if (selectedChunks.length > 1) {
                      return processAssociate(selectedChunks[1], false);
                  } else {
                      return Promise.resolve();
                  }
              })
              .then(function() {return getAssociateTotal()})
              .then(function(result) {
                  loadRecords();
                  setTotalAmountFromDB(result);
                  $('[id$="unassociationCompleteMessage"]').show();
              })
              .catch(function(exception) {
                  $('[id$="errorPanel"]').show();
                  $('[id$="errorPanel"]').find('h4').html('Error: ' + event.message);
              });
        }
        else {
            setTotalAmountFromTempStorage();
            loadRecords();
        }
    };

    ASModule.showOrHideDataPanel = function(isVisible) {
        if (isVisible) {
            $('[id$="loadingImage"]').hide();
            $('[id$="thePanel"]').show();
        }
        else {
            $('[id$="loadingImage"]').show();
            $('[id$="thePanel"]').hide();
        }
    };

    var removeUnusedData = function(data) {
        var fieldSet = ['Account__c', 'Account__r', 'Amount__c', 'Journal_Entry__c', 'Payee__c', 'Payment_Reference__c', 'Name', 'Payment_Reference__c', 'Reference__c', 'Credit__c', 'Debit__c', 'Date__c', 'Ledger_Amount__c', 'Receipt_Date__c'];
        fieldSet.forEach(function (s) {
            if (data.obj.hasOwnProperty(pq + s)) {
                delete data.obj[pq + s];
            }
        });
        data.name = '';
        data.money = {};
        data.customerName = '';
        data.sourceObj = {};
        data.reference = '';
        data.objDate = '';
        return data;
    };

    var checkedCount = function(tableType, checkBoxClass) {
        var count = 0;
        tableType.rows().every(function(rowIdx, tableLoop, rowLoop) {
            var checkbox = $(this.node()).find(checkBoxClass);
            if ($(checkbox).prop('checked')) {
                count ++;
            }
        });
        return count;
    };

    var loadRecords = function () {
        ASModule.getAssociatedRecords();
        ASModule.getUnassociatedRecords();
    };

    $(function() {
        if ($('[id$="dataTablePanel"]').length !== 0) {
            $.fn.dataTable.moment("DD/MM/YYYY", ASModule.defaultLocale);
            loadRecords();
        }
        setColorIfNegative($('[id$="totalAmount"]'));
        setColorIfNegative($('[id$="totalLedgerAmount"]'));
    });

    return ASModule;
  
})(window, document, $j, AcctSeed.ASModule);