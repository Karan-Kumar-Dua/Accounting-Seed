AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    var packageQualifier = ASModule.packageQualifier === undefined ? "" : ASModule.packageQualifier;

    ASModule.jQuerySelectorEscape = function(expression) {
        return expression.replace(/[!"#$%&'()*+,.\/:;<=>?@\[\\\]^`{|}~]/g, '').trim();
    };

    //Set Default GL Account
    ASModule.setDefaultGLAccount = function() {
        var glAccountName = $('[id$="defaultVendorGLAccount"]').val();
        var glAccountId = $('[id$="defaultVendorGLAccount_lkid"]').val();

        $('[id$="debitGLAccountLookup_lkid"]').each(function() {
            ASModule.setObjectValue(this, glAccountId);
            $(this).trigger('change');
        });

        $('[id$="debitGLAccountLookup"]').each(function() {
            ASModule.setObjectValue(this, glAccountName);
            $(this).trigger('change');
        });

        $('[id$="debitGLAccountLookup_lktp"]').each(function() {
            ASModule.setObjectValue(this, ASModule.gLAccountKeyPrefix);
            $(this).trigger('change');
        });
    };

    ASModule.clearGLAVsInGivenRow = function(row) {
        $(row).find(
            '[id$="glav1_lookup"], ' +
            '[id$="glav1_lookup_lkold"], ' +
            '[id$="glav1_lookup_lkid"], ' +
            '[id$="glav2_lookup"], ' +
            '[id$="glav2_lookup_lkold"], ' +
            '[id$="glav2_lookup_lkid"], ' +
            '[id$="glav3_lookup"], ' +
            '[id$="glav3_lookup_lkold"], ' +
            '[id$="glav3_lookup_lkid"], ' +
            '[id$="glav4_lookup"], ' +
            '[id$="glav4_lookup_lkold"], ' +
            '[id$="glav4_lookup_lkid"]'
        ).each(function() {
            this.value = '';
        });
    };

    //Processing GLAVs cells in related table row only
    ASModule.setGLAVsInGivenRow = function(result, event, row) {
        if (event.status) {
            ASModule.clearGLAVsInGivenRow(row);
            //GLAV 1
            if (result[packageQualifier + 'GL_Account_Variable_1__c'] != undefined) {
                $(row).find('[id$="glav1_lookup"],[id$="glav1_lookup_lkold"]').each(function() {
                    ASModule.setObjectValue(this, result[packageQualifier + 'GL_Account_Variable_1__r'].Name);
                });

                $(row).find('[id$="glav1_lookup_lkid"]').each(function() {
                    ASModule.setObjectValue(this, result[packageQualifier + 'GL_Account_Variable_1__c']);
                });
            }
            //GLAV 2
            if (result[packageQualifier + 'GL_Account_Variable_2__c'] != undefined) {
                $(row).find('[id$="glav2_lookup"],[id$="glav2_lookup_lkold"]').each(function() {
                    ASModule.setObjectValue(this, result[packageQualifier + 'GL_Account_Variable_2__r'].Name);
                });

                $(row).find('[id$="glav2_lookup_lkid"]').each(function() {
                    ASModule.setObjectValue(this, result[packageQualifier + 'GL_Account_Variable_2__c']);
                });
            }
            //GLAV 3
            if (result[packageQualifier + 'GL_Account_Variable_3__c'] != undefined) {
                $(row).find('[id$="glav3_lookup"],[id$="glav3_lookup_lkold"]').each(function() {
                    ASModule.setObjectValue(this, result[packageQualifier + 'GL_Account_Variable_3__r'].Name);
                });

                $(row).find('[id$="glav3_lookup_lkid"]').each(function() {
                    ASModule.setObjectValue(this, result[packageQualifier + 'GL_Account_Variable_3__c']);
                });
            }
            //GLAV 4
            if (result[packageQualifier + 'GL_Account_Variable_4__c'] != undefined) {
                $(row).find('[id$="glav4_lookup"],[id$="glav4_lookup_lkold"]').each(function() {
                    ASModule.setObjectValue(this, result[packageQualifier + 'GL_Account_Variable_4__r'].Name);
                });

                $(row).find('[id$="glav4_lookup_lkid"]').each(function() {
                    ASModule.setObjectValue(this, result[packageQualifier + 'GL_Account_Variable_4__c']);
                });
            }

        }
        else if (event.type === 'exception') {
            $('[id$="responseErrors"]').html(event.message).show();
        }
        else {
            $('[id$="responseErrors"]').html(event.message).show();
        }
    };

    ASModule.cleanAllLookupFields = function() {
        $('.lookupInput input').each(function() {
            $(this).val('');
        });
    };

    ASModule.setGLAccount = function(obj, callBackFunction) {
        var accountId = document.getElementById(obj.id + '_lkid').value;
        Visualforce.remoting.Manager.invokeAction(
            ASModule.getGLAccountRemoteMethod,
            accountId,
            function(result, event) {
                callBackFunction(result, event, obj);
            }, {
                buffer: true,
                escape: false,
                timeout: 120000
            }
        );
    };

    ASModule.setVendorResultGLAccount = function(obj) {
        //prevent update if Default Vendor Expense GL Account field has value
        var defaultVendorGLAccountId = $('[id$="defaultVendorGLAccount_lkid"]').val();
        if (checkIsEmptyValue(defaultVendorGLAccountId)) {
            ASModule.setGLAccount(obj, ASModule.setVendorResultGlAccountCallback);
        }
    };

    ASModule.setVendorResultGLAVs = function(obj) {
        var vendorId = document.getElementById(obj.id + '_lkid').value;
        //if GLAVs visibility are enabled in the table
        var showGLAVs = $('[id$="showGLAVS"]').prop('checked');
        //fill them accordingly
        if (showGLAVs && !checkIsEmptyValue(vendorId)) {//populate GLAVS from Default Vendor (Account)
            Visualforce.remoting.Manager.invokeAction(
                ASModule.queryDefaultVendor,
                vendorId,
                function(result, event) {
                    ASModule.setGLAVsInGivenRow(result, event, $(obj).parent().parent().parent().parent());//input -> span -> td -> tr
                }, {
                    buffer: true,
                    escape: false,
                    timeout: 120000
                }
            );
        }
    };

    ASModule.setVendorResultGlAccountCallback = function(result, event, obj) {
        if (event.status) {

            var glAccountId =
                obj.id.indexOf('vendorLookup') > -1 ? obj.id.split('vendorLookup', 1) + 'debitGLAccountLookup' : obj.id.split('customerLookup', 1) + 'creditGLAccountLookup';

            if (result[packageQualifier + 'Default_Expense_GL_Account__c'] !== undefined) {
                //put GL Account record Name and Id to the GL Account Column
                document.getElementById(glAccountId).value = result[packageQualifier + 'Default_Expense_GL_Account__r'].Name;
                document.getElementById(glAccountId + '_lkid').value = result[packageQualifier + 'Default_Expense_GL_Account__c'];
            }
            else {
                document.getElementById(glAccountId).value = '';
                document.getElementById(glAccountId + '_lkid').value = '';
            }
        }
        else if (event.type === 'exception') {
            document.getElementById("responseErrors").innerHTML = event.message;
        }
        else {
            document.getElementById("responseErrors").innerHTML = event.message;
        }
    };

    ASModule.setObjectValue = function(obj, newVal, dataSetFlag) {
        dataSetFlag = dataSetFlag || false;
        if (checkIsEmptyValue(obj.value)) {
            obj.value = newVal;
            $(obj).attr('data-set-flag', dataSetFlag);
        }
    };

    var checkIsEmptyValue = function (value) {
        if (value === null || value === "null" || value === '' || value === undefined || value === '000000000000000') {
            return true;
        }
        return false;
    };

    ASModule.disableCheckBoxes = function() {
        $('[id$="showProjects"]').prop('disabled', true);
        $('[id$="showGLAVS"]').prop('disabled', true);
    };

    ASModule.enableCheckBoxes = function() {
        $('[id$="showProjects"]').prop('disabled', false);
        $('[id$="showGLAVS"]').prop('disabled', false);
    };

    ASModule.fireOnChangeEvent = function() {
        $('[id$="vendorLookup"]').each(function() {
            $(this).trigger('change');
        });
    };

    //==========================================================================
    //===================== Radio buttons handlers =============================
    var originalRowObjCache;

    ASModule.matchingRowSelectionHandler = function(inputElement) {
        var key = $(inputElement).attr('name');
        var rowId = $(inputElement).parent().parent().attr('data-matching-row-id');
        highlightRow(rowId);

        if (originalRowObjCache === undefined || originalRowObjCache == null) {//create cache instance only once
            originalRowObjCache = new CustomMap();
        }

        var originalRowObj = {
            id: null,
            matchingFlag: false,
            acctPeriod: $(inputElement).closest('tr').find('td.acctPeriodColumn > div.tableCell'),
            vendor: $(inputElement).closest('tr').find('td.vendorColumn > div.tableCell'),
            glAccount: $(inputElement).closest('tr').find('td.glAccountColumn > div.tableCell'),
            cashFlowCategory: $(inputElement).closest('tr').find('td.cashFlowColumn > div.tableCell'),
            type: $(inputElement).closest('tr').find('td.typeColumn > div.tableCell'),
            project: $(inputElement).closest('tr').find('td.projectColumn > div.tableCell'),
            projectTask: $(inputElement).closest('tr').find('td.projectTaskColumn > div.tableCell'),
            glav1: $(inputElement).closest('tr').find('td.glav1Column > div.tableCell'),
            glav2: $(inputElement).closest('tr').find('td.glav2Column > div.tableCell'),
            glav3: $(inputElement).closest('tr').find('td.glav3Column > div.tableCell'),
            glav4: $(inputElement).closest('tr').find('td.glav4Column > div.tableCell')
        };

        if (originalRowObjCache.get(key) === null) {
            originalRowObjCache.set(key, originalRowObj);
        }

        copyFromMatchingRow(inputElement, rowId);
    };

    var copyFromMatchingRow = function(inputElement, rowId) {
        var matchingRowObj = {
            id: rowId,
            matchingFlag: true,
            acctPeriod: $("div[data-matching-row-id=\'" + rowId + "\'] > div.tableCell.acctPeriodCell"),
            vendor : $("div[data-matching-row-id=\'" + rowId + "\'] > div.tableCell.vendorCell"),
            glAccount: $("div[data-matching-row-id=\'" + rowId + "\'] > div.tableCell.glAccountCell"),
            cashFlowCategory: $("div[data-matching-row-id=\'" + rowId + "\'] > div.tableCell.cashFlowCell"),
            type: $("div[data-matching-row-id=\'" + rowId + "\'] > div.tableCell.typeCell"),
            project: $("div[data-matching-row-id=\'" + rowId + "\'] > div.tableCell.projectCell"),
            projectTask: $("div[data-matching-row-id=\'" + rowId + "\'] > div.tableCell.projectTaskCell"),
            glav1: $("div[data-matching-row-id=\'" + rowId + "\'] > div.tableCell.glav1Cell"),
            glav2: $("div[data-matching-row-id=\'" + rowId + "\'] > div.tableCell.glav2Cell"),
            glav3: $("div[data-matching-row-id=\'" + rowId + "\'] > div.tableCell.glav3Cell"),
            glav4: $("div[data-matching-row-id=\'" + rowId + "\'] > div.tableCell.glav4Cell")
        };

        $(inputElement).closest('tr').find('td.statusColumn input:hidden[id$="sfId"]').val(matchingRowObj.id);
        $(inputElement).closest('tr').find('td.statusColumn input:hidden[id$="matchingFlag"]').val(matchingRowObj.matchingFlag);
        $(inputElement).closest('tr').find('td.acctPeriodColumn > div.tableCell').replaceWith($(matchingRowObj.acctPeriod).clone());
        $(inputElement).closest('tr').find('td.vendorColumn > div.tableCell').replaceWith($(matchingRowObj.vendor).clone());
        $(inputElement).closest('tr').find('td.glAccountColumn > div.tableCell').replaceWith($(matchingRowObj.glAccount).clone());
        $(inputElement).closest('tr').find('td.cashFlowColumn > div.tableCell').replaceWith($(matchingRowObj.cashFlowCategory).clone());
        $(inputElement).closest('tr').find('td.typeColumn > div.tableCell').replaceWith($(matchingRowObj.type).clone());
        $(inputElement).closest('tr').find('td.projectColumn > div.tableCell').replaceWith($(matchingRowObj.project).clone());
        $(inputElement).closest('tr').find('td.projectTaskColumn > div.tableCell').replaceWith($(matchingRowObj.projectTask).clone());
        $(inputElement).closest('tr').find('td.glav1Column > div.tableCell').replaceWith($(matchingRowObj.glav1).clone());
        $(inputElement).closest('tr').find('td.glav2Column > div.tableCell').replaceWith($(matchingRowObj.glav2).clone());
        $(inputElement).closest('tr').find('td.glav3Column > div.tableCell').replaceWith($(matchingRowObj.glav3).clone());
        $(inputElement).closest('tr').find('td.glav4Column > div.tableCell').replaceWith($(matchingRowObj.glav4).clone());
    };

    ASModule.cancelSelectionHandler = function (inputElement) {
        $(inputElement).closest('tr').find('div.matchingRecord.selectedRow').each(function() {
            $(this).removeClass('selectedRow');
        });

        var originalRowObj = originalRowObjCache.get($(inputElement).attr('name'));

        if (originalRowObj !== undefined && originalRowObj != null) {
            $(inputElement).next().val(originalRowObj.id);
            $(inputElement).next().next().val(originalRowObj.matchingFlag);
            $(inputElement).closest('tr').find('td.acctPeriodColumn > div.tableCell').replaceWith($(originalRowObj.acctPeriod).clone());
            $(inputElement).closest('tr').find('td.vendorColumn > div.tableCell').replaceWith($(originalRowObj.vendor).clone());
            $(inputElement).closest('tr').find('td.glAccountColumn > div.tableCell').replaceWith($(originalRowObj.glAccount).clone());
            $(inputElement).closest('tr').find('td.cashFlowColumn > div.tableCell').replaceWith($(originalRowObj.cashFlowCategory).clone());
            $(inputElement).closest('tr').find('td.typeColumn > div.tableCell').replaceWith($(originalRowObj.type).clone());
            $(inputElement).closest('tr').find('td.projectColumn > div.tableCell').replaceWith($(originalRowObj.project).clone());
            $(inputElement).closest('tr').find('td.projectTaskColumn > div.tableCell').replaceWith($(originalRowObj.projectTask).clone());
            $(inputElement).closest('tr').find('td.glav1Column > div.tableCell').replaceWith($(originalRowObj.glav1).clone());
            $(inputElement).closest('tr').find('td.glav2Column > div.tableCell').replaceWith($(originalRowObj.glav2).clone());
            $(inputElement).closest('tr').find('td.glav3Column > div.tableCell').replaceWith($(originalRowObj.glav3).clone());
            $(inputElement).closest('tr').find('td.glav4Column > div.tableCell').replaceWith($(originalRowObj.glav4).clone());
        }
    };

    var highlightRow = function(rowId) {
        var selector = "div[data-matching-row-id=\'" + rowId + "\']";
        $(selector).each(function() {
            $(this).siblings().each(function () {
                $(this).removeClass('selectedRow');
            });

            $(this).addClass('selectedRow');
        });
    };

    //Custom MAP feature implementation ======================================
    function CustomMap() {
        this._data = {};
    };

    CustomMap.prototype = {

        get: function(key) {
            return this.has(key) ? this._data[key] : null;
        },

        has: function(key) {
            return Object.prototype.hasOwnProperty.call(this._data, key);
        },

        set: function(key, value) {
            this._data[key] = value;
        }
    };
    //========================================================================
    //==========================================================================
    //==========================================================================

    return ASModule;
})(window, document, $j, AcctSeed.ASModule);