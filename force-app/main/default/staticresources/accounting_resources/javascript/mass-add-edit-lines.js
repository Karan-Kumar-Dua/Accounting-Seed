AcctSeed.ASModule = (function(window, document, $, ASModule, i18n) {
    "use strict";

    var currencyFormatterProxy = ASModule.currencyFormatterProxy;
    var offset;
    var recLimit;
    var recordSetSize;
    var scrollLocTop;
    var scrollLocLeft;
    var isDirty = false;
    var lineTable;

    vex.defaultOptions.className = 'vex-theme-default';
    vex.dialog.buttons.YES.text = 'No';
    vex.dialog.buttons.NO.text = 'Yes';

    var formatTable = function () {
        var preDrawReturn = true;
        offset = parseInt($('[id$="offset"]').val());
        recLimit = parseInt($('[id$="recLimit"]').val());
        recordSetSize = parseInt($('[id$="recordSetSize"]').val());

        lineTable = $('[id$="lineTable"]').DataTable({
            "processing": false,
            "serverSide": true,
            "displayStart": offset,
            "lengthMenu": [ 10, 25 ],
            "pageLength": recLimit,
            "lengthChange": true,
            "deferLoading": recordSetSize,
            "ordering": false,
            "searching": false,
            "order": [],
            "preDrawCallback": function() {
                return preDrawReturn;
            },
            "drawCallback": function(settings) {
                configureEventHandlers();
            },
            "language": i18n && i18n.datatables
        });

        $('[id$="lineTable"]').on('length.dt', function ( e, settings, len) {
            recLimit = len;
            offset = 0;
            $('[id$="recLimit"]').val(recLimit);
            $('[id$="offset"]').val(offset);
            refreshTable();
        });

        preDrawReturn = false;
    };

    var configureEventHandlers = function() {
        $('.dataTables_paginate a').on('click', function() {
            var that = this;
            var preventAction = false;

            var callBackAction = function(value) {
                if (!value) {
                    isDirty = false;
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
                offset = (offset - recLimit) < 0 ? 0 : offset - recLimit;
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

        $('[id$="lineTable"] input').on('keyup change', function() {
            isDirty = true;
        });
    };

    var openConfirm = function(actionCallback) {
        vex.dialog.confirm({
            message: ASModule?.LABELS?.CONFIRM_DO_YOU_WANT_TO_LEAVE_THIS_PAGE_SAVE,
            callback: function(value) {
                actionCallback(value);
            }
        });
    };

    ASModule.hidePanel = function (panelId) {
        var panelSelector = '[id$="' + panelId + '"]';
        $(panelSelector).css('visibility', 'hidden');
    };

    ASModule.showPanel = function (panelId) {
        var panelSelector = '[id$="' + panelId + '"]';
        $(panelSelector).css('visibility', 'visible');
    };

    ASModule.loadingTable = function(val) {
        if (val) {
            scrollLocTop = $(window).scrollTop();
            scrollLocLeft = $(window).scrollLeft();
            ASModule.hidePanel('thePanel');
            ASModule.hidePanel('lineTablePanel');
        }
        else {
            $(window).scrollTop(scrollLocTop);
            $(window).scrollLeft(scrollLocLeft);
            ASModule.showPanel('thePanel');
            ASModule.showPanel('lineTablePanel');
        }
    };

    ASModule.refreshTableIfNoErrors = function(isError) {
        var isVFFrameworkErrors = checkVFFrameworkErrorsExist();
        if (!isError && !isVFFrameworkErrors) {
            refreshTable();
        }
        else {
            ASModule.pageLoad();
            ASModule.showPanel('thePanel');
            ASModule.showPanel('lineTablePanel');
        }
    };

    ASModule.redirectToNewIfNoErrors = function(isError, objApiName) {
        var isVFFrameworkErrors = checkVFFrameworkErrorsExist();
        if (!isError && !isVFFrameworkErrors) {
            if ((typeof sforce != 'undefined') && sforce && (!!sforce.one)) {
                sforce.one.createRecord(objApiName, null);
            }
            else {
                redirectToNew();
            }
        }
    };

    var checkVFFrameworkErrorsExist = function() {
        if ($(".errorM3").length) {
            return true;
        }
        else {
            return false;
        }
    };

    ASModule.disableDeleteAbility = function () {
        $('[id$="deleteStatus.stop"] a').each(function() {
            $(this).prop("onclick", false);
            $(this).attr('href', 'javascript:void(0);');
            $(this).css('text-decoration', 'none');
            $(this).find('span').text('Processing...');
        });
    };

    ASModule.redrawTable = function(edited) {
        isDirty = edited;
        ASModule.pageLoad();
        ASModule.showPanel('lineTablePanel');
    };

    ASModule.pageLoad = function() {
        formatTable();
        handleCustomOutput();
    };

    var handleCustomOutput = function() {
        var isMultiCurrencyEnabled =
            ASModule.isMultiCurrencyEnabled !== undefined
                ? ((ASModule.isMultiCurrencyEnabled == 'true') ? true : false)
                : false;

        if (isMultiCurrencyEnabled) {
            $('.masterCurrencyField, .detailCurrencyField').each(function() {
                if (!$(this).hasClass('formatted')) {
                    $(this).text(currencyFormatterProxy($(this).text()));
                    $(this).addClass('formatted');
                }
            });
        }

    };

    $(function() {
        ASModule.pageLoad();
        ASModule.showPanel('thePanel');
        ASModule.showPanel('lineTablePanel');
        $(document).keydown(function(e) {
            if (e.keyCode === 13 && !e.shiftKey) {
                ASModule.saveAndRefresh();
            }
        });
    });

    return ASModule;

})(window, document, $j, AcctSeed.ASModule, AcctSeed.i18n);
