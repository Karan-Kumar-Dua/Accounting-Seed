AcctSeed.ASModule = (function(window, document, $, ASModule) {

    var fileTable;

    ASModule.formatTable = function() {
        fileTable = $('[id$="fileTable"]').DataTable({
            "paging": true,
            "lengthChange": false,
            "pageLength": 10,
            "searching": true,
            "ordering": true,
            "columnDefs":[{
                targets: 2,
                "render": function(data, type, row, meta) {
                    var fSize = $(data).text().replace(/,/g, '');
                    return ASModule.fileSizeFormatter(fSize, 3);
                }
            }]
        });
    };

    ASModule.passSalesforceFileToParent = function(id, name, size, isLinked, statementMode) {
        var winMain = window.opener;
        if (null == winMain) {
            winMain = window.parent.opener;
        }

        var customEmailAttachments = [{
            fileId: id,
            fileName: name,
            fileSize: size,
            isLinkedWithEntity: isLinked
        }];
        winMain.AcctSeed.ASModule.addAttachments(customEmailAttachments, statementMode);
        closeWindow();
    };

    ASModule.passNewFilesToParent = function(customEmailAttachments, statementMode) {
        var winMain = window.opener;
        if (null == winMain) {
            winMain = window.parent.opener;
        }
        var deserializedArray = JSON.parse(customEmailAttachments);
        winMain.AcctSeed.ASModule.addAttachments(deserializedArray, statementMode);
        closeWindow();
    };

    var closeWindow = function() {
        var winMain = window.opener;
        if (null == winMain) {
            winMain = window.parent.opener;
        }
        winMain.AcctSeed.ASModule.closeCustomFilePicker();
    };

    ASModule.formatFileSizeColumn = function() {
        $('.uploadedFileSize').each(function() {
            var fSize = $(this).text().replace(/,/g, '');
            $(this).text(ASModule.fileSizeFormatter(fSize, 3));
        });
    };

    $(function() {
        ASModule.formatFileSizeColumn();
    });

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);