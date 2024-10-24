AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    var scrollLocTop;
    var scrollLocLeft;
    var importTable;

    vex.defaultOptions.className = 'vex-theme-default';
    vex.dialog.buttons.YES.text = 'No';
    vex.dialog.buttons.NO.text = 'Yes';
    var offset;
    var recLimit;
    var recordSetSize;
    var isDirty = false;

    var formatTable = function() {
        var preDrawReturn = true;
        offset = parseInt($('[id$="offset"]').val());
        recLimit = parseInt($('[id$="recLimit"]').val());
        recordSetSize = parseInt($('[id$="recordSetSize"]').val());
        isDirty = false;

        importTable = $('[id$="importTable"]').DataTable({
            "processing": false,
            "serverSide": true,
            "displayStart": offset,
            "pageLength": recLimit,
            "lengthChange": false,
            "deferLoading": recordSetSize,
            "order": [
                [2, 'asc']
            ],
            "ordering": false,
            "searching": false,
            "preDrawCallback": function() {
                return preDrawReturn;
            },
            "drawCallback": function(settings) {
                configureEventHandlers();
            }
        });
        preDrawReturn = false;
    };

    var configureEventHandlers = function() {
        $('.dataTables_paginate a').on('click', function() {
            var that = this;
            var preventAction = false;

            var callBackAction = function(value) {
                if (!value) {
                    ASModule.cleanAllLookupFields();
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
            else if ($(that).hasClass('first')) {
                offset = 0;
            }
            else if ($(that).hasClass('last')) {
                offset = recordSetSize;
            }
            else {
                offset = (parseInt($(that).text(), 10) - 1) * recLimit;
            }

            $('[id$="offset"]').val(offset);
            refreshTable();
        });

        $('[id$="periodLookup"],[id$="customerLookup"],[id$="vendorLookup"],[id$="creditGLAccountLookup"],[id$="debitGLAccountLookup"]').on('keyup change', function() {
            isDirty = true;
        });

        $('.matchingRadioButton').on('click', function() {
            if (this.value === 'none') {
                ASModule.cancelSelectionHandler(this);
            }
            else {
                ASModule.matchingRowSelectionHandler(this);
            }
        });
    };

    var openConfirm = function(actionCallback) {
        vex.dialog.confirm({
            message: 'Do you want to leave this page? You have unsaved changes.<br/>Click Create Records to commit your changes.',
            callback: function(value) {
                actionCallback(value);
            }
        });
    };

    var pageLoad = function() {
        formatTable();
    };

    ASModule.redrawTable = function() {
        pageLoad();
    };

    ASModule.loadingTable = function(val) {
        if (val) {
            scrollLocTop = $(window).scrollTop();
            scrollLocLeft = $(window).scrollLeft();
            $('[id$="thePanel"]').css('visibility', 'hidden');
        }
        else {
            $(window).scrollTop(scrollLocTop);
            $(window).scrollLeft(scrollLocLeft);
            $('[id$="thePanel"]').css('visibility', 'visible');
        }
    };

    ASModule.findDirtyInputFieldWithError = function() {
        var inputFieldsWithError = $('[id$="importTable"] .errorMsg').size();
        if (inputFieldsWithError > 0) {
            isDirty = true;
        }
    };

    $(function() {
        $('<iframe name="verifyframe" width="100%" height="800"/>').appendTo('#iframeDiv').attr({
            'id': 'verifyframe'
        });
        $('#verifyForm').submit();
        formatTable();
    });

    ASModule.reloadIFrame = function() {
        $('#verifyForm').submit();
    };

    ASModule.preventFormSubmitIfDateFieldIsEmpty = function(obj) {
        if (obj.value == null || obj.value == '' || obj.value == undefined) {
            $('[id$="showProjects"]').attr('disabled', true);
            $('[id$="showGLAVS"]').attr('disabled', true);
        }
        else if ($('[id$="startDateField"]').val() && $('[id$="endDateField"]').val()) {
            $('[id$="showProjects"]').removeAttr('disabled');
            $('[id$="showGLAVS"]').removeAttr('disabled');
        }
    };

    ASModule.enableButtons = function() {
        $('[class*="pbButton"] > .btnDisabled').prop('disabled', false).attr('class', 'btn');
        $('[id$="search"]').val('Search');
        $('[id$="back"]').val('Back');
        $('[id$="createButton"]').val('Create/Update Records');
        $('[id$="matchButton"]').val('Find Matching Data');
        $('[id$="populateGLAccountButton"]').val('Mass Populate GL Account');
        $('[id$="saveButton"]').val('Save');
        $('[id$="refreshButton"]').val('Refresh');
    };

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);