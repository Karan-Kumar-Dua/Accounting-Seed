AcctSeed.ASModule = (function(window, document, $, ASModule) {

    //============================================================================================================
    //===== A dependency exists with this file and the purchase order create PDF functionality in the ERP package.
    //============================================================================================================

    "use strict";

    var attachments = [];
    var attachmentTable;

    ASModule.addAttachments = function(customEmailAttachments, statementMode) {
        attachments = attachments.concat(customEmailAttachments);
        formatAttachments(attachments);
    };

    var formatAttachments = function (dataSource) {
        if (attachmentTable !== undefined) {//if DataTable was initiated before
            attachmentTable.destroy();
        }
        attachmentTable = $('[id$="mainTable"]').DataTable({
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
                "render": function(data, type, row, meta) {
                    return ASModule.fileSizeFormatter(data, 3);
                },
                "className": "dt-head-right dt-body-right"
            }, {
                "title": "Action",
                "data": "fileId",
                "render": function(data, type, row, meta) {
                    return "<a href='#' id='" + data + "' class='cancelAttachment'><span style='color: red;'>Cancel</span></a>";
                },
                "className": "dt-head-center dt-body-center"
            }]
        });

        $('[id$="proxyInput"]').val(JSON.stringify(dataSource));
        $('.cancelAttachment').on('click', function(){
            var that = this;
            removeAttachment($(that).attr('id'));
        });
    };

    var removeAttachment = function (attachmentId) {
        var newArray = [];
        for (var i = 0; i < attachments.length; i++) {
            if (attachments[i].fileId !== attachmentId) {
                newArray.push(attachments[i]);
            }
        }

        attachments = newArray;
        formatAttachments(attachments);
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

    ASModule.setContact = function(itemId, contactId) {
        Visualforce.remoting.Manager.invokeAction(
            ASModule.setContactRemote,
            itemId,
            contactId,
            handleResult, {
                escape: false,
                timeout: 120000
            }
        );

        function handleResult(result, event) {
            if (event.status) {
                if (result.isValidContact) {
                    if (typeof CKEDITOR === 'undefined' || CKEDITOR === null) {//Regular Text Area
                        if ($('[id$="emailSubject"]').val() == '') {
                            $('[id$="emailSubject"]').val(result.template.emailSubject);
                        }
                        if ($('[id$="emailBody"]').val() == '') {
                            $('[id$="emailBody"]').val(result.template.emailBody);
                        }
                    }
                    else {//Rich Text Area
                        if ($('[id$="emailSubject"]').val() == '') {
                            $('[id$="emailSubject"]').val(result.template.emailSubject);
                        }
                        var ckEditorInstance = $('[id$="emailBody"]').attr("id");
                        var emailBody = result.template.emailBody;
                        if (CKEDITOR.instances[ckEditorInstance].getData() == '') {
                            CKEDITOR.instances[ckEditorInstance].setData(emailBody);
                        }
                    }

                    $('[id$="emailAttachButton"]').attr('disabled', false);
                    $('[id$="emailAttachButton"]').addClass("btn");
                    $('[id$="emailAttachButton"]').removeClass("btnDisabled");
                    $('[id$="errorPanel"]').hide();
                }
                else {
                    handleError(result.errorMessage);
                }
            }
            else {
                handleError(event.message);
            }
        };
    };

    var handleError = function(errorMessage) {
        displayErrorPanel(errorMessage);
        $('[id$="emailAttachButton"]').attr('disabled', 'disabled');
        $('[id$="emailAttachButton"]').addClass("btnDisabled");
    };

    var displayErrorPanel = function(errorMessage) {
        if (errorMessage) {
            $('[id$="errorPanel"]').show();
            $('[id$="errorPanel"]').html('Error: ' + errorMessage);
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

    $(window).on('load', function() {
        $('#loader1').css("display", "none");
    });

    $(document).ready(function() {
        if ($('[id$="proxyInput"]').val() !== '') {
            ASModule.addAttachments(JSON.parse($('[id$="proxyInput"]').val()));
        }
    });

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);