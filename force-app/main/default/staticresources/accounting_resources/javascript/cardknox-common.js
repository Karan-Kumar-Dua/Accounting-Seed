window.AcctSeed = typeof window.AcctSeed !== 'undefined' ? window.AcctSeed : {};
var AcctSeed = window.AcctSeed;

AcctSeed.ASModule = (function (document) {
  "use strict";
    var defaultStyle = {
        borderRadius: '4px',
        border: '1px solid rgb(118, 118, 118)',
        paddingRight: '10px',
        paddingLeft: '10px',
        width: '10.6rem',
        height : '25px',
        marginLeft: '50px !important',
        float: 'left'   
    };
    var errorStyle = {
        borderRadius: '4px',
        border: '1px solid red',
        paddingRight: '10px',
        paddingLeft: '10px',
        width: '10.6rem',
        height : '25px',
        marginLeft: '50px !important',
        float: 'left'   
    };
    var clear = function () {
        setCardknoxAccount(document.getElementsByClassName('updatedIFieldsKey')[0].innerHTML);
        clearIfield('ach');
        clearIfield('card-number');
        clearIfield('cvv');

        $('#name, #month, #year, #nameAch, #routing, #account-number').val('');
        enableButtons();
        $('#submitPaymentBtn, #submitPaymentBtn2').prop('disabled', false);
    };
    var enableButtons = function() {
        $('.pbButton > .btn, .pbButtonb > .btn').each(function() {
            var buttonName = $(this).attr('name');
            if ($(this).attr('name').indexOf('cancelButton') != -1) {
                buttonName = 'Back';
            }
            if ($(this).attr('name').indexOf('submitPayment') != -1) {
                if ($('[id$="tabs"]').length) {
                    buttonName = 'Create Payment Method';
                }
                else {
                    buttonName = 'Create Payment';
                }
            }
            $(this).removeClass('btnDisabled').prop('disabled', false).val(buttonName);
        });
    };

    var overridePageMessages = function() {
        $('.infoM3').addClass('slds-notify slds-notify--toast customMessage ');
        $('.infoM3').removeClass('infoM3');
    };

    var disableButtons = function(label) {
        $('.pbButton > .btn, .pbButtonb > .btn').toggleClass('btnDisabled').prop('disabled', true).val(label);
    };

    var loadingTable = function(val) {
        if (val) {
            $('.paymentMethodTable').css('visibility', 'hidden');
        }
        else {
            $('.paymentMethodTable').css('visibility', 'visible');
        }
    };
    var setActiveTab = function(element) {
        $('.slds-tabs_scoped__item').each(function() {
            $(this).removeClass("slds-is-active");
        });
        $(element).addClass("slds-is-active");
    };
    var manageInitialButton = function () {
        if ($('[id$="tabs"]').length) {
            $('[id$="tabs"]').tabs();
            $('.slds-tabs_scoped__item').click(function() {
                setActiveTab($(this));
            });
            document.getElementById('spinner').className = document.getElementById('spinner').className += ' slds-hide ';
        }
    };
    var switchStatusOfPaymentMethodJS = function(paymentMethodId, tabNumber) {

        var label = 'Are you sure you want to change the Payment Method\'s status?';

        if (confirm(label)) {
            if (tabNumber === 0) {
                switchStatusOfPaymentMethod(paymentMethodId);
            }
            else if (tabNumber === 1) {
                switchStatusOfPaymentMethod2(paymentMethodId);
            }
        }
        else {
            return false;
        }
    };
    var setDefaultPaymentMethodJS = function(paymentMethodId, tabNumber) {

        var label = 'Are you sure you want to make this Payment method as Default?';

        if (confirm(label)) {
            if (tabNumber === 0) {
                setDefaultPaymentMethod(paymentMethodId);
            }
            else if (tabNumber === 1) {
                setDefaultPaymentMethod2(paymentMethodId);
            }
        }
        else {
            return false;
        }
    };
    var processorChanged = function(picklist) {
        var el = document.getElementById(picklist);
        var i = el.selectedIndex;
        var selectedProcessor = el.options[i].value;
        var inputs = $('.processor-select-input');
        for (var input of inputs) {
            input.selectedIndex = i;
        }
        updateProcessor(selectedProcessor);
    };
    var submitForm = function (event) {
        getTokens(function (event) {
            var card = document.querySelector("[data-ifields-id='card-number-token']").value;
            var cvv = document.querySelector("[data-ifields-id='cvv-token']").value;
            var expM = document.getElementById('month').value;
            var expY = document.getElementById('year').value;
            var name = document.getElementById('name').value;

            let listElements = '<p style="margin-left:-22px;">Required Fields Are Missing:</p>';
            listElements += enforceCardValidations('card-number', card, 'Card Number');
            listElements += enforceValidation('month',expM,'Month');
            listElements += enforceValidation('year',expY,'Year');

            if (listElements.endsWith('</li>')) {
                document.getElementById('card-errors').innerHTML = listElements;
                return;
            }
            let qualify = doQualityCheck(card, 'card-number', 'Card Number','card-errors');
            if (!qualify) { return;}
            passToController(card, expM, expY, name);
        },
        function (error) {
            console.error(error);
        },
        30000
        );
    };
    var enforceCardValidations = function (elementId, value, name) {
        if (value !== '') {
            setIfieldStyle(elementId, defaultStyle);
            return;
        }
        let item = '<li style="margin-left:-22px;">' + name + '</li>';
        setIfieldStyle(elementId, errorStyle);
        return item;
    }
    var enforceValidation = function (elementId, value, name) {
        let element = $('#' + elementId);
        if (value !== '') {
            element[0].className = 'InputFieldNormal';
            return '';
        }
        let item = '<li style="margin-left:-22px;">' + name + '</li>';
        element[0].className = 'InputFieldError'; 
        return item;
    }
    var submitFormACH = function (event) {        
        getTokens(function () {
            var ach = document.querySelector("[data-ifields-id='ach-token']").value;
            var routing = document.getElementById('routing').value;
            var name = document.getElementById('nameAch').value;

            let listElements = '<p style="margin-left:-22px;">Required Fields Are Missing:</p>';
            listElements += enforceValidation('nameAch',name,'Name');
            listElements += enforceCardValidations('ach', ach, 'Account Number');
            listElements += enforceValidation('routing',routing,'Routing Number');

            if (listElements.endsWith('</li>')) {
                document.getElementById('card-errors-ach').innerHTML = listElements;
                return;
            }
            let qualify = doQualityCheck(ach, 'ach', 'Account Number','card-errors-ach');
            if (!qualify) { return;}
            achInputsFromJS(ach, routing,name);
        },
          function () {
            document.getElementById('ach-token').innerHTML = '';
          },
          30000
        );
    };

    var doQualityCheck = function (value, elementId, messageFor, errorLogId) {
        let error = '<p style="margin-left:-22px;">Invalid ' + messageFor + '! make sure your ' + messageFor + ' is correct!</p>';
        
        if (value.includes('error') || value.includes('unknown') ) {
            document.getElementById(errorLogId).innerHTML = error;
            setIfieldStyle(elementId, errorStyle);
            return false;
        }
        document.getElementById(errorLogId).innerHTML = '';
        setIfieldStyle(elementId, defaultStyle);
        return true;
    }
    var init = function () {

        setIfieldStyle('ach', defaultStyle);
        setIfieldStyle('card-number', defaultStyle);
        setIfieldStyle('cvv', defaultStyle);

        setCardknoxAccount(window.AcctSeed.IFieldsKey);
        overridePageMessages();
        var checkCardLoaded = setInterval(function () {
            clearInterval(checkCardLoaded);
            focusIfield('name');
        }, 1000);
        manageInitialButton();
    };
    var setCardknoxAccount = function (ifieldsKey) {
        setAccount(ifieldsKey, "AcctSeed", "1.0.0");
    };

    init();
    return {
        submitForm : submitForm,
        submitFormACH: submitFormACH,
        processorChanged: processorChanged,
        setDefaultPaymentMethodJS: setDefaultPaymentMethodJS,
        switchStatusOfPaymentMethodJS: switchStatusOfPaymentMethodJS,
        loadingTable : loadingTable,
        clear: clear,
        disableButtons : disableButtons
    };

})(document);