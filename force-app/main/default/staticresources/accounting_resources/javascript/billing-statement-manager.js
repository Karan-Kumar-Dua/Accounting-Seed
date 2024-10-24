AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    var outstandingAttachments = [];
    var activityAttachments = [];
    var outstandingAttachmentsTable;
    var activityAttachmentsTable;

    ASModule.addAttachments = function(customEmailAttachments, statementMode) {
        if (statementMode == 'outstanding') {
            outstandingAttachments = outstandingAttachments.concat(customEmailAttachments);
            formatOutstandingAttachments(outstandingAttachments);
        }
        else {
            activityAttachments = activityAttachments.concat(customEmailAttachments);
            formatActivityAttachments(activityAttachments);
        }
    };

    var formatOutstandingAttachments = function(dataSource) {
        if (outstandingAttachmentsTable !== undefined) {//if DataTable was initiated before
            outstandingAttachmentsTable.destroy();
        }
        outstandingAttachmentsTable = $('[id$="outstandingAttachmentsTable"]').DataTable({
            "data": dataSource,
            "paging": false,
            "lengthChange": false,
            "pageLength": 10,
            "searching": false,
            "ordering": false,
            "info": false,
            "autoWidth": false,
            "columns":[{
                "title": "Name",
                "data": "fileName"
            }, {
                "title": "Size",
                "data": "fileSize",
                "render": function(data, type, row, meta){
                    return ASModule.fileSizeFormatter(data, 3);
                },
                "className": "dt-head-right dt-body-right"
            }, {
                "title": "Action",
                "data": "fileId",
                "render": function(data, type, row, meta){
                    return "<a href='#' id='" + data + "' class='cancelOutstandingAttachment'><span style='color: red;'>Cancel</span></a>";
                },
                "className": "dt-head-center dt-body-center"
            }]
        });

        //===== This is workaround for apex:tabPanel + JSON.stringify() not usual output
        var dataSourceString = JSON.stringify(dataSource);
        dataSourceString = dataSourceString.substring(1, dataSourceString.length - 1);//remove first and last quotes
        dataSourceString = dataSourceString.replace(/\\"/g, '"');//remove escaped quotes
        //==========================================================================================================

        $('[id$="outstandingProxyInput"]').val(dataSourceString);
        $('.cancelOutstandingAttachment').on('click', function(){
            var that = this;
            removeAttachment($(that).attr('id'), 'outstanding');
        });
    };

    var formatActivityAttachments = function(dataSource) {
        if (activityAttachmentsTable !== undefined) {//if DataTable was initiated before
            activityAttachmentsTable.destroy();
        }
        activityAttachmentsTable = $('[id$="activityAttachmentsTable"]').DataTable({
            "data": dataSource,
            "paging": false,
            "lengthChange": false,
            "pageLength": 10,
            "searching": false,
            "ordering": false,
            "info": false,
            "autoWidth": false,
            "columns":[{
                "title": "Name",
                "data": "fileName"
            }, {
                "title": "Size",
                "data": "fileSize",
                "render": function(data, type, row, meta){
                    return ASModule.fileSizeFormatter(data, 3);
                },
                "className": "dt-head-right dt-body-right"
            }, {
                "title": "Action",
                "data": "fileId",
                "render": function(data, type, row, meta){
                    return "<a href='#' id='" + data + "' class='cancelActivityAttachment'><span style='color: red;'>Cancel</span></a>";
                },
                "className": "dt-head-center dt-body-center"
            }]
        });

        //===== This is workaround for apex:tabPanel + JSON.stringify() not usual output
        var dataSourceString = JSON.stringify(dataSource);
        dataSourceString = dataSourceString.substring(1, dataSourceString.length - 1);//remove first and last quotes
        dataSourceString = dataSourceString.replace(/\\"/g, '"');//remove escaped quotes
        //==========================================================================================================

        $('[id$="activityProxyInput"]').val(dataSourceString);
        $('.cancelActivityAttachment').on('click', function(){
            var that = this;
            removeAttachment($(that).attr('id'), 'activity');
        });
    };

    var removeAttachment = function(attachmentId, statementMode) {
        var newArray = [];
        var arrayToChange = (statementMode == 'outstanding') ? outstandingAttachments : activityAttachments;
        for (var i = 0; i < arrayToChange.length; i++) {
            if (arrayToChange[i].fileId !== attachmentId) {
                newArray.push(arrayToChange[i]);
            }
        }

        if (statementMode == 'outstanding') {
            outstandingAttachments = newArray;
            formatOutstandingAttachments(outstandingAttachments);
        }
        else {
            activityAttachments = newArray;
            formatActivityAttachments(activityAttachments);
        }
    };

    ASModule.setCustomStyleOnBtn = function(label) {
        $(".btn").toggleClass("btnDisabled").val(label);
    };

    ASModule.newWin = null;

    ASModule.openCustomFilePicker = function(pageURL) {
        var url = pageURL;
        ASModule.newWin = window.open(
            url, 'Popup', 'height=550,width=780,left=200,top=200,resizable=no,scrollbars=no,toolbar=no,status=no'
        );
        if (window.focus) {
            ASModule.newWin.focus();
        }

        return false;
    };

    ASModule.closeCustomFilePicker = function() {
        if (null != ASModule.newWin) {
            ASModule.newWin.close();
        }
    };

    ASModule.setContact = function(billingId, contactId, statementType, ledgerId) {
        Visualforce.remoting.Manager.invokeAction(
            ASModule.setContactRemote,
            billingId,
            contactId,
            statementType,
            ledgerId,
            handleResult, {
                escape: false,
                timeout: 120000
            }
        );

        function handleResult(result, event) {
            if (event.status) {
                if (result.isValidContact) {
                    if (typeof CKEDITOR === 'undefined' || CKEDITOR === null) {//Regular Text Area
                        if (statementType === 'outstanding') {
                            if ($('[id$="outstandingEmailSubject"]').val() == '') {
                                $('[id$="outstandingEmailSubject"]').val(result.template.emailSubject);
                            }
                            if ($('[id$="outstandingEmailBody"]').val() == '') {
                                $('[id$="outstandingEmailBody"]').val(result.template.emailBody);
                            }
                        }
                        else {
                            if ($('[id$="activityEmailSubject"]').val() == '') {
                                $('[id$="activityEmailSubject"]').val(result.template.emailSubject);
                            }
                            if ($('[id$="activityEmailBody"]').val() == '') {
                                $('[id$="activityEmailBody"]').val(result.template.emailBody);
                            }
                        }
                    }
                    else {//Rich Text Area
                        if (statementType === 'outstanding') {
                            if ($('[id$="outstandingEmailSubject"]').val() == '') {
                                $('[id$="outstandingEmailSubject"]').val(result.template.emailSubject);
                            }
                            var ckEditorInstance = $('[id$="outstandingEmailBody"]').attr("id");
                            var emailBody = result.template.emailBody;
                            if (CKEDITOR.instances[ckEditorInstance].getData() == '') {
                                CKEDITOR.instances[ckEditorInstance].setData(emailBody);
                            }
                        }
                        else {
                            if ($('[id$="activityEmailSubject"]').val() == '') {
                                $('[id$="activityEmailSubject"]').val(result.template.emailSubject);
                            }
                            var ckEditorInstance = $('[id$="activityEmailBody"]').attr("id");
                            var emailBody = result.template.emailBody;
                            if (CKEDITOR.instances[ckEditorInstance].getData() == '') {
                                CKEDITOR.instances[ckEditorInstance].setData(emailBody);
                            }
                        }
                    }

                    $('[id$="emailAttachButton1"],[id$="emailAttachButton2"]').attr('disabled', false);
                    $('[id$="emailAttachButton1"],[id$="emailAttachButton2"]').addClass("btn");
                    $('[id$="emailAttachButton1"],[id$="emailAttachButton2"]').removeClass("btnDisabled");
                    $('[id$="outstandingErrorPanel"],[id$="activityErrorPanel"]').hide();
                }
                else {
                    handleError(result.errorMessage, statementType);
                }
            }
            else {
                handleError(event.message, statementType);
            }
        };
    };

    var handleError = function(errorMessage, statementType) {
        displayErrorPanel(errorMessage, statementType);
        if (statementType === 'outstanding') {
            $('[id$="emailAttachButton1"]').attr('disabled', 'disabled');
            $('[id$="emailAttachButton1"]').addClass("btnDisabled");
        }
        else {
            $('[id$="emailAttachButton2"]').attr('disabled', 'disabled');
            $('[id$="emailAttachButton2"]').addClass("btnDisabled");
        }

    };

    var displayErrorPanel = function(errorMessage, statementType) {
        if (errorMessage) {
            if (statementType === 'outstanding') {
                $('[id$="outstandingErrorPanel"]').show();
                $('[id$="outstandingErrorPanel"]').html('Error: ' + errorMessage);
            }
            else {
                $('[id$="activityErrorPanel"]').show();
                $('[id$="activityErrorPanel"]').html('Error: ' + errorMessage);
            }
        }
    };



    ASModule.setCustomStyleOnBtn = function(label) {
        $(".btn").toggleClass("btnDisabled").val(label);
    };

    ASModule.showTab1Buttons = function() {
        $('[id*=saveAttachButton1]').show();
        $('[id*=emailAttachButton1]').show();
    };

    ASModule.showTab2Buttons = function() {
        $('[id*=saveAttachButton2]').show();
        $('[id*=emailAttachButton2]').show();
    };

    ASModule.hideFrame1 = function() {
        $('#loader1').css("display", "none");
    };

    ASModule.hideFrame2 = function() {
        $('#loader2').css("display", "none");
    };

    ASModule.loadFrame1 = function() {
        ASModule.hideFrame1();
        ASModule.showTab1Buttons();
        ASModule.refreshAttachments();
    };

    ASModule.loadFrame2 = function() {
        ASModule.hideFrame2();
        ASModule.showTab2Buttons();
        ASModule.refreshAttachments();
    };

    ASModule.refreshAttachments = function () {
        if ($('[id$="outstandingProxyInput"]').length && $('[id$="outstandingProxyInput"]').val() !== '') {
            outstandingAttachments = [];
            ASModule.addAttachments(JSON.parse($('[id$="outstandingProxyInput"]').val()), 'outstanding');
        }
        if ($('[id$="activityProxyInput"]').length && $('[id$="activityProxyInput"]').val() !== '') {
            activityAttachments = [];
            ASModule.addAttachments(JSON.parse($('[id$="activityProxyInput"]').val()), 'activity');
        }
    };

    ASModule.validateEmails = function({EMAIL_ERROR_CC_ADDRESSES_ARE_NOT_VALID}) {
        $('[id$="emailErrorPanel"]').hide();
        var result = true;
        $('.tag').each(function() {
            if ($(this).hasClass('notValid')) {
                result = false;
            }
        });

        if (!result) {
            $('[id$="emailErrorPanel"]').show();
            $('[id$="emailErrorPanel"]').find('h4').html(EMAIL_ERROR_CC_ADDRESSES_ARE_NOT_VALID);
            return false;
        }

        return ASModule.setCustomStyleOnBtn('Processing...');
    };
    $(window).on('load', function(){
        ASModule.loadFrame1();
        ASModule.loadFrame2();
    });

    $(document).ready(function() {
        ASModule.refreshAttachments();
    });

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);