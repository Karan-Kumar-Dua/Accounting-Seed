AcctSeed.ASModule = (function(window, document, $, ASModule, i18n) {

    var numberParser = ASModule.numberParser;
    var isTableExist = $('[id$="forecastTable"]').find('tr')[0];
    var columnCount = isTableExist ? $('[id$="forecastTable"]').find('tr')[0].cells.length : 10;

    if (isTableExist) {
        $.extend( $.fn.dataTableExt.oSort, {
            "formatted_numbers-pre": function ( a ) {
                a = (a===" " || a==="") ? '0' : a.replace( /<\/?[\w\s="/.':;#-\/\?]+>/g, "" );
                var negative = a.includes('(');
                a = a.match(/[-,]?\d+(?:\.\d+)?/g).join('');
                if (negative) {
                    a = '-' + a;
                }
                return  numberParser(a);
            },

            "formatted_numbers-asc": function ( a, b ) {
                return a - b;
            },

            "formatted_numbers-desc": function ( a, b ) {
                return b - a;
            }
        } );
    }

    var forecastTable;
    var statisticsTable;
    var systemExceptionTable;

    var formatTable = function() {
        forecastTable = $('[id$="forecastTable"]').DataTable({
            "paging": true,
            "lengthChange": false,
            "pageLength": 25,
            "searching": false,
            "columnDefs": [
                { type: "formatted_numbers",
                  targets: columnCount > 10 ? [2,3,4] : [2,3]
                }
            ],
            "language": i18n && i18n.datatables
        });

        statisticsTable = $('[id$="errorStatisticsTable"]').DataTable({
            "paging": true,
            "lengthChange": false,
            "pageLength": 25,
            "searching": false,
            "ordering": true,
            "drawCallback": function( settings ) {
                handleNavigationLinks();
            },
            "language": i18n && i18n.datatables
        });

        $('#spinner').css('display', 'none');
        $('[id$="forecastTable"]').css('visibility', 'visible');
        $('[id$="errorStatisticsTable"]').css('visibility', 'visible');
    };

    ASModule.formatSystemExceptionTable = function () {
        systemExceptionTable = $('[id$="systemExceptionTable"]').DataTable({
            "paging": true,
            "lengthChange": false,
            "pageLength": 25,
            "searching": false,
            "ordering": true,
            "language": i18n && i18n.datatables
        });

        $('#spinner2').css('display', 'none');
        $('[id$="systemExceptionTable"]').css('visibility', 'visible');
    };

    ASModule.hideSpinner = function() {
        $('#spinner').css('display', 'none');
        $('[id$="forecastTable"]').css('display', 'none');
        $('[id$="errorStatisticsTable"]').css('display', 'none');
    };

    ASModule.gotoSource = function(targetId) {
        sforce.one.navigateToSObject(targetId);
    };

    function handleNavigationLinks() {
        //workaround for
        //"navigation links on the batch post and unpost screens do not work correctly in lightning experience"
        if ((typeof sforce != 'undefined') && sforce && (!!sforce.one)) {

            $(".sourceLink").each(function() {
                var targetId = $(this).attr('data-sourceid');
                var baseUrl = window.location.origin;
                //in case of regular click
                var onClick = "javascript:AcctSeed.ASModule.gotoSource('" + targetId + "');return false;";
                //in case of right click and "Open link in new tab" option
                var hrefValue = baseUrl + "/one/one.app#/sObject/" + targetId + "/view";
                $(this).attr('href', hrefValue);
                $(this).attr('onClick', onClick);
            });
        }
    };

    $(function() {
        formatTable();
    });

    return ASModule;

})(window, document, $j, AcctSeed.ASModule, AcctSeed.i18n);

