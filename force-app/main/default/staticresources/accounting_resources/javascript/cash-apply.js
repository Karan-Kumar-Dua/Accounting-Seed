AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";
    
    var currencyFormatterProxy = ASModule.currencyFormatterProxy;
    var numberParser = ASModule.numberParser;
    var numberFormatter = ASModule.numberFormatter;
    var sumColumnAndSetTotal = ASModule.sumColumnAndSetTotal;
    var refreshTable = ASModule.refreshTable;
    var scrollLocTop;
    var scrollLocLeft;

    vex.defaultOptions.className = 'vex-theme-default';
    vex.dialog.buttons.YES.text = 'No';
    vex.dialog.buttons.NO.text = 'Yes';
    var theTable;
    var offset;
    var recLimit;
    var recordSetSize;
    var isDirty = false;

    ASModule.redrawTable = function() {
        ASModule.pageLoad();

        var isError = $('[id$="isError"]').val() === "true" ? true : false;
        if (!isError) {
            isDirty = false;
        }
        $('[id$="thePanel"]').css('visibility','visible');
    };

    /*
    * This function returns
    * Non sortable columns for every possible state of the table
    * Currently suitable for tables on the next pages:
    * ==================
    * Apply Cash Receipt
    * Account Payable Apply Credit Memo
    * Billing Apply Credit Memo
    * Apply Cash Disbursement
    * ==================
    * Possible state of a table:
    * Set1. Customer Column ON || Button Column ON
    * Set2. Customer Column OFF || Button Column ON
    * Set3. Customer Column ON || Button Column OFF
    * Set4. Customer Column OFF || Button Column OFF
    * */
    var provideNonSortColumns = function(tableId, isCustomerColumnDisplayed, isFromToButtonColumnDisplayed, fieldListSize) {
        var resultColumnsSet;
        var fs = fieldListSize;

        var applyCashReceiptNonSortColumnsSet1 = [fs+2,fs+4,fs+5,fs+6,fs+7,fs+8];
        var applyCashReceiptNonSortColumnsSet2 = [fs+1,fs+3,fs+4,fs+5,fs+6,fs+7];
        var applyCashReceiptNonSortColumnsSet3 = [fs+2,fs+4,fs+5,fs+6,fs+7];
        var applyCashReceiptNonSortColumnsSet4 = [fs+1,fs+3,fs+4,fs+5,fs+6];

        var apApplyCreditMemoSet2 = [5,7,8,9];//with Button Column
        var apApplyCreditMemoSet4 = [5,7,8];//without Button Column

        var billingApplyCreditMemoSet1 = [5,7,8,9];
        var billingApplyCreditMemoSet2 = [4,6,7,8];
        var billingApplyCreditMemoSet3 = [5,7,8];
        var billingApplyCreditMemoSet4 = [4,6,7];

        var applyCashDisbursementSet2 = [5,7,8,9];//with Button Column
        var applyCashDisbursementSet4 = [5,7,8];//without Button Column

        if (tableId == 'theBillingTable') {
            if (isCustomerColumnDisplayed && isFromToButtonColumnDisplayed) {
                resultColumnsSet = applyCashReceiptNonSortColumnsSet1;
            }
            else if (!isCustomerColumnDisplayed && isFromToButtonColumnDisplayed) {
                resultColumnsSet = applyCashReceiptNonSortColumnsSet2;
            }
            else if (isCustomerColumnDisplayed && !isFromToButtonColumnDisplayed) {
                resultColumnsSet = applyCashReceiptNonSortColumnsSet3;
            }
            else if (!isCustomerColumnDisplayed && !isFromToButtonColumnDisplayed) {
                resultColumnsSet = applyCashReceiptNonSortColumnsSet4;
            }
        }
        else if (tableId == 'theAPMemoTable') {
            if (isFromToButtonColumnDisplayed) {
                resultColumnsSet = apApplyCreditMemoSet2;
            }
            else if (!isFromToButtonColumnDisplayed) {
                resultColumnsSet = apApplyCreditMemoSet4;
            }
        }
        else if (tableId == 'theBillingMemoTable') {
            if (isCustomerColumnDisplayed && isFromToButtonColumnDisplayed) {
                resultColumnsSet = billingApplyCreditMemoSet1;
            }
            else if (!isCustomerColumnDisplayed && isFromToButtonColumnDisplayed) {
                resultColumnsSet = billingApplyCreditMemoSet2;
            }
            else if (isCustomerColumnDisplayed && !isFromToButtonColumnDisplayed) {
                resultColumnsSet = billingApplyCreditMemoSet3;
            }
            else if (!isCustomerColumnDisplayed && !isFromToButtonColumnDisplayed) {
                resultColumnsSet = billingApplyCreditMemoSet4;
            }
        }
        else if (tableId == 'theCDApplyTable') {
            if (isFromToButtonColumnDisplayed) {
                resultColumnsSet = applyCashDisbursementSet2;
            }
            else if (!isFromToButtonColumnDisplayed) {
                resultColumnsSet = applyCashDisbursementSet4;
            }
        }
        return resultColumnsSet;
    };

    var formatTable = function() {
        var preDrawReturn = true;
        offset = parseInt($('[id$="offset"]').val());
        recLimit = parseInt($('[id$="recLimit"]').val());
        recordSetSize = parseInt($('[id$="recordSetSize"]').val());
        var sortFieldIndex = parseInt($('[id$="sortFieldIndex"]').val());
        var sortOrderIndex = parseInt($('[id$="sortOrderIndex"]').val());
        var fieldListSize = parseInt($('[id$="fieldListSize"]').val());
        var sortOrder = (sortOrderIndex === 0 ? "asc" : "desc");
        var nonSortColumns;
        var tableSelector;
        //Apply Cash Receipt
        if ($('[id$="theBillingTable"]').length !== 0) {
            tableSelector = $('[id$="theBillingTable"]');
            nonSortColumns = provideNonSortColumns("theBillingTable", ($('[id$="customerColumn"]').length !== 0), ($('[id$="buttonPanel"]').length !== 0), fieldListSize);
            isDirty = false;
        }
        //Account Payable Apply Credit Memo
        else if ($('[id$="theAPMemoTable"]').length !== 0) {
            tableSelector = $('[id$="theAPMemoTable"]');
            nonSortColumns = provideNonSortColumns("theAPMemoTable", null, ($('[id$="buttonPanel"]').length !== 0));
            isDirty = false;
        }
        //Billing Apply Credit Memo
        else if ($('[id$="theBillingMemoTable"]').length !== 0) {
            tableSelector = $('[id$="theBillingMemoTable"]');
            nonSortColumns = provideNonSortColumns("theBillingMemoTable", ($('[id$="customerColumn"]').length !== 0), ($('[id$="buttonPanel"]').length !== 0));
            isDirty = false;
        }
        //Apply Cash Disbursement
        if ($('[id$="theCDApplyTable"]').length !== 0) {
            tableSelector = $('[id$="theCDApplyTable"]');
            nonSortColumns = provideNonSortColumns("theCDApplyTable", ($('[id$="customerColumn"]').length !== 0), ($('[id$="buttonPanel"]').length !== 0));
            isDirty = false;
        }

        theTable = tableSelector.DataTable({
            "processing": false,
            "serverSide": true,
            "displayStart": offset,
            "pageLength": recLimit,
            "lengthMenu": [10, 25],
            "deferLoading": recordSetSize,
            "order": [
                [sortFieldIndex, sortOrder],
            ],
            "columnDefs": [{
                "targets": nonSortColumns,
                "orderable": false
            }],
            "searching": false,
            "preDrawCallback": function () {
                return preDrawReturn;
            },
            "drawCallback": function( settings ) {
                configureEventHandlers();
            }                                    
        });
        preDrawReturn = false;
    };

    var configureEventHandlers = function() {
        $('.dataTables_length').find('select').on('change', function(){
            var that = this;

            var callBackAction = function(value) {
                if (!value) {
                    isDirty = false;
                    $(that).change();
                }
                else {
                    var selectedIndex = $(that).prop("selectedIndex") === 1 ? 0 : 1;
                    $(that).prop("selectedIndex",selectedIndex);
                }                     
            };

            if (isDirty) {
                openConfirm(callBackAction);
                return false;
            }

            $('[id$="recLimit"]').val( $(this).val() );
            $('[id$="offset"]').val(0);

            refreshTable();

        });

        $('.sorting,.sorting_asc,.sorting_desc').on('click',function(){
            var that = this;

            var callBackAction = function(value) {
                if (!value) {
                    isDirty = false;
                    $('[id$="isError"]').val("false");
                    $(that).click();
                }
            };

            if (isDirty) {
                openConfirm(callBackAction);
                return false;
            }

            $('[id$="sortFieldIndex"]').val( $(this).index() );

            var sortOrderIndex = $('[id$="sortOrderIndex"]').val();
            sortOrderIndex = sortOrderIndex === "1" ? "0" : "1";
            $('[id$="sortOrderIndex"]').val(sortOrderIndex);
            refreshTable();
            
        });

        $('[id$="from"]').on('click', function(){
            var that = this;
            isDirty = true;
            populateReceivedAmount(that.id);
        });

        $('[id$="to"]').on('click', function(){
            var that = this;
            isDirty = true;
            clearReceivedAmount(that.id);
        });

        $('[id$="receivedAmount"]').on('keyup change', function(){
            var that = this;
            isDirty = true;
            updateReceivedAmount(that);
        });

        $('[id$="accountingPeriod"],[id$="adjustmentGLAccount"]').on('change', function(e){
            isDirty = true;
        });

        $('[id$="adjustmentAmount"]').on('keyup change', function(){
            var that = this;
            isDirty = true;
            updateAdjustmentAmount(that);
        });

        $('.dataTables_paginate a').on('click', function(){
            var that = this;
            var preventAction = false;

            var callBackAction = function(value) {
                if (!value) {
                    isDirty = false;
                    $('[id$="isError"]').val("false");
                    $(that).click();
                }
            };

            if ($(that).hasClass('previous') && offset === 0) {
                preventAction = true;
            }
            else if ($(that).hasClass('next') && (offset + recLimit) >= recordSetSize) {
                preventAction = true;
            }

            if (preventAction) {
                return false;
            }

            if (isDirty) {
                openConfirm(callBackAction);
                return false;
            }

            if ($(that).hasClass('previous')) {
                 offset = offset = offset - recLimit;
            }
            else if ($(that).hasClass('next')) {
                offset = offset + recLimit;
            }
            else if($(that).hasClass('first')) {
                offset = 0;
            }
            else if($(that).hasClass('last')) {
                offset = recordSetSize;
            }
            else {
                offset = (parseInt($(that).text(),10)-1)*recLimit;
            }

            $('[id$="offset"]').val(offset);
            refreshTable();
        });
    };
    
    var openConfirm = function(actionCallback) {
        vex.dialog.confirm({
            message: ASModule?.LABELS?.CONFIRM_DO_YOU_WANT_TO_LEAVE_THIS_PAGE,
            callback: function(value) {
                actionCallback(value);
            }
        });
    };

    ASModule.disableArrowButtons = function() {
        $('.arrowButton').css("color","GrayText").attr("cursor","default").prop('disabled',true);                         
    };

    var updateApplyBalance = function(lineNum) {
        var applyBalanceField = $('[id$=":applyBalanceAmount"]');
        var applyAmount = numberParser($('[id$=":applyAmount"]').text());
        var applyAppliedAmount = numberParser($('[id$=":applyAppliedAmount"]').text());
        applyBalanceField.text(currencyFormatterProxy(applyAmount - applyAppliedAmount));
    };

    var updateBalance = function(lineNum) {
        var balanceField = $('[id$=":' + lineNum + ':balanceAmount"]');
        var billingAmount =
            $('[id$=":' + lineNum + ':billingAmount"]').length > 0
                ? $('[id$=":' + lineNum + ':billingAmount"]').text()
                : '0';
        // Discount info is only for informational purposes and should not be used to calculate
        // Total Applied or Billing Balance amounts
        // if this code is used for Cash Receipt Apply screen
        var discountAmount;
        if (($('[id$="theBillingTable"]').length === 0) && ($('[id$=":' + lineNum + ':discountAmount"]').length > 0)) {
            discountAmount = $('[id$=":' + lineNum + ':discountAmount"]').text();
        }
        else {
            discountAmount = '0';
        }
        //Tax Amount will be excluded if this is Reverse-Charge Tax Amount on CD Apply Screen
        var taxAmount;
        if (($('[id$="theBillingTable"]').length === 0) && ($('[id$=":' + lineNum + ':taxAmount"]').length > 0)) {
            taxAmount = $('[id$=":' + lineNum + ':taxAmount"]').text();
        }
        else {
            taxAmount = '0';
        }

        var appliedAmount =
            $('[id$=":' + lineNum + ':appliedAmount"]').length > 0
                ? $('[id$=":' + lineNum + ':appliedAmount"]').text()
                : '0';
        var balanceAmount = numberParser(billingAmount) - numberParser(discountAmount) - numberParser(taxAmount) - numberParser(appliedAmount);
        balanceField.text(currencyFormatterProxy(Math.round10(balanceAmount, -2)));
    };

    var updateAppliedAmount = function(lineNum) {
        var appliedAmountField = $('[id$=":' + lineNum + ':appliedAmount"]');
        var appliedAmountOrig = numberParser($('[id$=":' + lineNum + ':appliedAmountOrig"]').text());
        var receivedAmount = numberParser($('[id$=":' + lineNum + ':receivedAmount"]').val() ? $('[id$=":' + lineNum + ':receivedAmount"]').val() : '0');
        var adjustmentAmount = numberParser($('[id$=":' + lineNum + ':adjustmentAmount"]').length > 0 && $('[id$=":' + lineNum + ':adjustmentAmount"]').val() ? $('[id$=":' + lineNum + ':adjustmentAmount"]').val() : '0');
        appliedAmountField.text(currencyFormatterProxy(appliedAmountOrig + receivedAmount + adjustmentAmount));
    };

    var populateReceivedAmount = function(id) {
        var lineNum = getLineNum(id);
        var receivedAmountField = $('[id$=":' + lineNum + ':receivedAmount"]');
        var cashReceiptBalance = numberParser($('[id$=":applyBalanceAmount"]').text());
        var receivedAmount = numberParser($('[id$=":' + lineNum + ':balanceAmount"]').text());

        if (cashReceiptBalance < receivedAmount) {
           receivedAmount = cashReceiptBalance;
        }
        
        if (cashReceiptBalance < 0 || receivedAmount < 0) {
           receivedAmount = 0;
        }

        receivedAmountField.val(numberFormatter(receivedAmount));
        updateAppliedAmount(lineNum);

        updateBalance(lineNum);

        updateTotals();
        updateApplyBalance(lineNum);

        $('[id$=":' + lineNum + ':from"]').hide();
        $('[id$=":' + lineNum + ':to"]').show();
        $('[id$=":' + lineNum + ':accountingPeriodRequired"]').show();
    };
    
    var clearReceivedAmount = function(id) {
        var lineNum = getLineNum(id);
        $('[id$=":' + lineNum + ':receivedAmount"]').val('');
        if ($('[id$=":' + lineNum + ':adjustmentAmount"]').length > 0) {
            $('[id$=":' + lineNum + ':adjustmentAmount"]').val('');
        }

        updateAppliedAmount(lineNum);
        updateBalance(lineNum);

        updateTotals();
        updateApplyBalance(lineNum);

        $('[id$=":' + lineNum + ':from"]').show();
        $('[id$=":' + lineNum + ':to"]').hide();
        $('[id$=":' + lineNum + ':accountingPeriodRequired"]').hide();                     
    };

    var updateReceivedAmount = function(obj) {
        var lineNum = getLineNum(obj.id);
        var receivedAmountField = $('[id$=":' + lineNum + ':receivedAmount"]');
        var cashReceiptBalance = numberParser($('[id$=":applyBalanceAmount"]').text());

        updateAppliedAmount(lineNum);
        updateBalance(lineNum);

        updateTotals();
        updateApplyBalance(lineNum);

        if ($(obj).val()) {
            $('[id$=":' + lineNum + ':from"]').hide();
            $('[id$=":' + lineNum + ':to"]').show();                        
            $('[id$=":' + lineNum + ':accountingPeriodRequired"]').show();
        } 
        else {
            $('[id$=":' + lineNum + ':from"]').show();
            $('[id$=":' + lineNum + ':to"]').hide();                        
            $('[id$=":' + lineNum + ':accountingPeriodRequired"]').hide();
        }                      
    };

    var updateAdjustmentAmount = function(obj) {
        var lineNum = getLineNum(obj.id);
        updateAppliedAmount(lineNum);
        updateBalance(lineNum);
        updateTotals();
        // updateAppliedAmount(lineNum);

        if ($(obj).val()) {
            $('[id$=":' + lineNum + ':adjustmentGLAccountRequired"]').show();
        } 
        else {
            $('[id$=":' + lineNum + ':adjustmentGLAccountRequired"]').hide();
        }                    
    };

    ASModule.noenter = function(e) {
        var key;

        if (window.event) {
            key = window.event.keyCode; //IE
        }
        else {
            key = e.which; //firefox
        }

        if (key == 13) {
            var ele = $('[id$="saveButtonTop"]');
            ele.click();
            return false;
        } 
        else {
            return true;
        }
    };

    var getLineNum = function(id) {
        return id.split(":")[5];
    };
    
    var updateTotals = function() {
        sumColumnAndSetTotal('[id$="receivedAmount"],[id$="appliedApplyAmountOrig"],[id$="billingAppliedAmount"]','[id$="applyAppliedAmount"]');
    };

    ASModule.loadingTable = function(val) {
        if (val) {
          scrollLocTop = $(window).scrollTop();
          scrollLocLeft =  $(window).scrollLeft();
          $('[id$="thePanel"]').css('visibility','hidden');
        }
        else {
          $(window).scrollTop(scrollLocTop);
          $(window).scrollLeft(scrollLocLeft);
          $('[id$="thePanel"]').css('visibility','visible');
        }
    }; 

    ASModule.pageLoad = function() {
        updateTotals();
        $('[id$="appliedAmount"],[id$="balanceAmount"],[id$="applyBalanceAmount"],[id$="applyAmount"],[id$="billingAmount"],[id$="discountAmount"],[id$="billingAppliedAmount"],[id$="adjustmentDisplayAmount"]').each(function() {
            $(this).text(currencyFormatterProxy($(this).text()));
        });
        updateApplyBalance();
        $('[id$="receivedAmount"],[id$="adjustmentAmount"]').attr('maxlength','10');
        formatTable();
    };

    $(function() {
        ASModule.pageLoad();
        $('[id$="thePanel"]').css('visibility','visible');
    });  

    return ASModule;
    
})(window, document, $j, AcctSeed.ASModule);