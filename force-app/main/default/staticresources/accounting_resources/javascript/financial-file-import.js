AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    var theTable;

    ASModule.disableButtons = function(label) {
        $('[class*="pbButton"] > .btn').prop('disabled', true).val(label).toggleClass('btnDisabled');
        $('[class*="dataTables_paginate"],[id*="theTable_length"],[id*="theTable_filter"]').hide();
    };

    ASModule.enableButtons = function() {
        $('[class*="pbButton"] > .btnDisabled').prop('disabled', false).attr('class', 'btn');
        $('[id*="createButton"]').val('Create Records');
        $('[id*="matchButton"]').val('Find Vendor Matches');
        $('[id*="defaultVendorButton"]').val('Populate Default Vendor');
        $('[class*="dataTables_paginate"],[id*="theTable_length"],[id*="theTable_filter"]').show();
    };

    ASModule.disableImportButtons = function(label) {
        $('.btn').val(label).toggleClass('btnDisabled');
    };

    ASModule.submitForm = function() {
        theTable.rows().nodes().page.len(-1).draw(false);
    };
    
    ASModule.setLookupFieldElements = function() {
        $('[id$="vendorLookup"]').each(function() {
            new ForeignKeyInputElement(this.id, "/_ui/common/data/LookupValidationServlet", null, true, {
                "acent": "001",
                "aclkent": ASModule.cashDisbursementKeyPrefix
            });
        });

        $('[id$="customerLookup"]').each(function() {
            new ForeignKeyInputElement(this.id, "/_ui/common/data/LookupValidationServlet", null, true, {
                "acent": "001",
                "aclkent": ASModule.cashReceiptKeyPrefix
            });
        });

        $('[id$="periodLookup"]').each(function() {
            new ForeignKeyInputElement(this.id, "/_ui/common/data/LookupValidationServlet", null, true, {
                "acent": ASModule.accountingPeriodKeyPrefix
            });
        });
                
        $('[id$="debitGLAccountLookup"]').each(function() {
            new ForeignKeyInputElement(this.id, "/_ui/common/data/LookupValidationServlet", null, true, {
                "acent": ASModule.gLAccountKeyPrefix,
                "aclkent": ASModule.cashDisbursementKeyPrefix
            });
        });

        $('[id$="creditGLAccountLookup"]').each(function() {
            new ForeignKeyInputElement(this.id, "/_ui/common/data/LookupValidationServlet", null, true, {
                "acent": ASModule.gLAccountKeyPrefix,
                "aclkent": ASModule.cashReceiptKeyPrefix
            });
        });

    };
    
    ASModule.formatTable = function() {
        theTable = $('[id$="theTable"]').DataTable({
            "ordering": false,
            "searching": false,
            "lengthMenu": [50, 100, 200, 500],
            "pageLength": 50,
            "order": [
                [2, 'asc']
            ],
            "drawCallback": function(settings) {
                configureEventHandlers();
            }
        });

        theTable.on('draw.dt', function() {
            ASModule.fireOnChangeEvent();
            ASModule.setLookupFieldElements();
        });

    };

    var configureEventHandlers = function() {
        $('.matchingRadioButton').on('click', function() {
            if (this.value === 'none') {
                ASModule.cancelSelectionHandler(this);
            }
            else {
                ASModule.matchingRowSelectionHandler(this);
            }
        });
    };

    ASModule.hideTable = function() {
        $('[id$="theTable_wrapper"]').hide();
    };

    ASModule.showTable = function() {
        $('[id$="theTable_wrapper"]').show();
    };
    
    ASModule.checkFileSize = function() {
        var theFile = $('[id$="file"]')[0].files[0];

        if (theFile != null && theFile != undefined && theFile.size > 1000000) {
            alert('import file cannot be over 1 MB in size.');
            $('[class*="pbButton"] > .btnDisabled').prop('disabled', false).attr('class', 'btn').val('Import');;
            return false;
        }

        return true;
    };

    $(document).ready(function() {
        ASModule.formatTable();
        ASModule.setLookupFieldElements();
        $('[id$="nameColumn"]').each(function() {
            $(this).attr('data-atr', ASModule.jQuerySelectorEscape($(this).attr('data-atr')));
        });
        $('#resultsSection').show();
    });

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);