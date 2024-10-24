AcctSeed.ASModule = (function(window, document, $, ASModule) {
    "use strict";

    var stripeObj;
    var card;
    var elements;
    var errorElement;
    var publishableKey = ASModule.platformPublishableKey;
    var connectedAccountId = ASModule.stripeConnectedId;
    var noStripeConnectedId = ASModule.noStripeConnectedId;    

    ASModule.disableButtons = function(label) {
        $('.pbButton > .btn, .pbButtonb > .btn').toggleClass('btnDisabled').prop('disabled', true).val(label);
    };

    ASModule.loadingTable = function(val) {
        if (val) {
            $('.paymentMethodTable').css('visibility', 'hidden');
        }
        else {
            $('.paymentMethodTable').css('visibility', 'visible');
        }
    };

    ASModule.deletePaymentMethodJS = function(paymentMethodId, label) {
        if (confirm(label)) {
            deletePaymentMethod(paymentMethodId);
        }
        else {
            return false;
        }
    };

    ASModule.switchStatusOfPaymentMethodJS = function(paymentMethodId, tabNumber) {

        var label = ASModule?.LABELS?.INF_CHANGE_PAYMENT_METHOD_STATUS;

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

    ASModule.setDefaultPaymentMethodJS = function(paymentMethodId, tabNumber) {

        var label = ASModule?.LABELS?.INF_CHANGE_PAYMENT_METHOD_AS_DEFAULT;

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

    ASModule.verifyBankAccountJS = function(paymentMethodId) {
        vex.defaultOptions.className = 'vex-theme-default';
        vex.dialog.prompt({
            message: 'Microdeposit amounts in cents.',
            input: [
                '<style>',
                    '.vex-custom-field-wrapper {',
                        'display: inline-flex;',
                        'margin: 1em 0;',
                    '}',
                    '.vex-custom-field-wrapper > label {',
                        'width: 140px;',
                        'margin-bottom: .2em;',
                    '}',
                '</style>',
                '<div class="vex-custom-field-wrapper">',
                    '<label for="firstDeposit">First deposit</label>',
                    '<div class="vex-custom-input-wrapper">',
                        '<input name="firstDeposit" type="text" pattern="[0-9]{2}" value="" title="Two-digit positive number for an amount in cents"/>',
                    '</div>',
                '</div>',
                '<div class="vex-custom-field-wrapper">',
                    '<label for="secondDeposit">Second deposit</label>',
                    '<div class="vex-custom-input-wrapper">',
                        '<input name="secondDeposit" type="text" pattern="[0-9]{2}" value="" title="Two-digit positive number for an amount in cents"/>',
                    '</div>',
                '</div>'
            ].join(''),
            callback: function(data) {
                if (data) {
                    verifyBankAccount(paymentMethodId, data.firstDeposit, data.secondDeposit);
                }
            }
        });
    };

    ASModule.submitPaymentForm = function() {
        $('.submitPaymentBtn').prop('disabled', true);
        var cardHolderName = $('#cardholder-name').val();
        stripeObj.createToken(card, {"name":cardHolderName}).then(function(result) {
            if (result.error) {
                // Inform the user if there was an error
                $(errorElement).text(result.error.message);
                $('.submitPaymentBtn').prop('disabled', false);
            }
            else {
                // Send the token to your server
                ASModule.stripeTokenHandler(result.token, false);
            }
        });
        return false;
    };

    ASModule.submitPaymentForm2 = function() {
        $('#ach-errors,#ach-error-routing-nmb,#ach-error-account-nmb').empty();
        $('#routing-number,#account-number').removeClass('ErrorInputField');
        $('.submitPaymentBtn2').prop('disabled', true);
        var accountHolderName = $('#accountholder-name').val();
        var accountHolderType = $('#accountholder-type').val();
        var routingNumber = $('#routing-number').val();
        var accountNumber = $('#account-number').val();

        var routingNumberEmptyErrorMsg = ASModule?.LABELS?.ERR_SPECIFY_ROUTING_NUMBER;
        var accountNumberEmptyErrorMsg = ASModule?.LABELS?.ERR_SPECIFY_ACCOUNT_NUMBER;

        if (!routingNumber && !accountNumber) {
            $('#ach-error-routing-nmb').text(routingNumberEmptyErrorMsg);
            $('#ach-error-account-nmb').text(accountNumberEmptyErrorMsg);
            $('#routing-number,#account-number').addClass('ErrorInputField');
            $('.submitPaymentBtn2').prop('disabled', false);
        }
        else if (!routingNumber) {
            $('#ach-error-routing-nmb').text(routingNumberEmptyErrorMsg);
            $('#routing-number').addClass('ErrorInputField');
            $('.submitPaymentBtn2').prop('disabled', false);
        }
        else if (!accountNumber) {
            $('#ach-error-account-nmb').text(accountNumberEmptyErrorMsg);
            $('#account-number').addClass('ErrorInputField');
            $('.submitPaymentBtn2').prop('disabled', false);
        }
        else {
            stripeObj.createToken('bank_account', {
                "country":"US",
                "currency":"usd",
                "routing_number": routingNumber,
                "account_number": accountNumber,
                "account_holder_name": accountHolderName,
                "account_holder_type": accountHolderType
            }).then(function(result) {
                if (result.error) {
                    // Inform the user if there was an error
                    $('#ach-errors').text(result.error.message);
                    $('.submitPaymentBtn2').prop('disabled', false);
                }
                else {
                    // Send the token to your server
                    ASModule.stripeTokenHandler(result.token, true);
                }
            });
        }

        return false;
    };

    ASModule.stripeTokenHandler = function(token, isACH) {
        // Insert the token ID into the form so it gets submitted to the server
        if (isACH) {
            createACHPayment(JSON.stringify(token));
        }
        else {
            createPayment(JSON.stringify(token));
        }
    };

    ASModule.clearForm = function() {
        card.clear();
        $('#cardholder-name, #accountholder-name, #routing-number, #account-number').val('');
        ASModule.enableButtons();
        $('.submitPaymentBtn, .submitPaymentBtn2').prop('disabled', false);
    };

    ASModule.enableButtons = function() {
        $('.pbButton > .btn, .pbButtonb > .btn').each(function() {
            var buttonName = $(this).attr('name');
            if ($(this).attr('name').indexOf('cancelButton') != -1) {
                buttonName = ASModule?.LABELS?.COMMON_BACK;
            }
            if (~$(this).attr('name').indexOf('receivePayment')) {
                buttonName = ASModule?.LABELS?.INF_RECEIVE_PAYMENT;
            }
            if ($(this).attr('name').indexOf('submitPayment') != -1) {
                if ($('[id$="tabs"]').length) {
                    buttonName = ASModule?.LABELS?.COMMON_CREATE_PAYMENT_METHOD;
                }
                else {
                    buttonName = ASModule?.LABELS?.COMMON_CREATE_PAYMENT;
                }
            }
            $(this).removeClass('btnDisabled').prop('disabled', false).val(buttonName);
        });
    };

    ASModule.initStripeElements = function() {
        errorElement = $('[id$="card-errors"]');
        if (publishableKey && connectedAccountId) {
            stripeObj = Stripe(publishableKey, {stripeAccount: connectedAccountId});
            // Create an instance of Elements
            elements = stripeObj.elements();
            // Create an instance of the card Element
            card = elements.create('card', {"hidePostalCode":true});
            // Add an instance of the card Element into the `card-element` <div>
            card.mount('#card-element');
            card.addEventListener('change', function(event) {
                if (event.error) {
                    $(errorElement).text(event.error.message);
                }
                else {
                    $(errorElement).text('');
                }
            });
        }
        else {
            $(errorElement).text(
                ASModule?.LABELS?.ERR_AUTHORIZATION_PUBLISHABLE_KEY + publishableKey +
                ASModule?.LABELS?.ERR_AUTHORIZATION_CONNECTED_ACCOUNT_ID + connectedAccountId
            );
        }
    };

    ASModule.reInitStripeElements = function(connectId, pKey) {
        ASModule.stripeConnectedId = connectId;
        connectedAccountId = connectId;
        ASModule.platformPublishableKey = pKey;
        publishableKey = pKey;
        ASModule.initStripeElements();
    }

    ASModule.setActiveTab = function(element) {
        $('.slds-tabs_scoped__item').each(function() {
            $(this).removeClass("slds-is-active");
        });
        $(element).addClass("slds-is-active");
    };

    ASModule.overridePageMessages = function() {
        $('.warningM3').addClass('slds-notify slds-notify--toast slds-theme--warning customMessage ');
        $('.confirmM3').addClass('slds-notify slds-notify--alert slds-theme--success  customMessage ');
        $('.errorM3').addClass('slds-notify slds-notify--alert slds-theme--error customMessage ');
        $('.infoM3').addClass('slds-notify slds-notify--toast customMessage ');

        $('.errorM3').removeClass('errorM3');
        $('.confirmM3').removeClass('confirmM3');
        $('.infoM3').removeClass('infoM3');
        $('.warningM3').removeClass('warningM3');
    };

    ASModule.updateProcessor = function(picklist) {
        var el = document.getElementById(picklist);
        var i = el.selectedIndex;
        var selectedProcessor = el.options[i].value;
        var inputs = $('.processor-select-input');
        for (var input of inputs) {
            input.selectedIndex = i;
        }
        updateProcessor(selectedProcessor);
    };

    ASModule.disableInput = function(selector) {  
        $(selector).prop('disabled', true);
    };

    ASModule.enableInput = function(selector) { 
        var el = $(selector);
        el.prop('disabled', false);
        el.focus();
        ASModule.enableButtons();
    };

    var debounce = function(fn, wait = 1000){
        let timer;
        return (...args) => {
            clearTimeout(timer);
            timer = setTimeout(() => { fn.apply(this, args); }, wait);
        };
    };

    ASModule.handleAmountChange = debounce(() => updateFees());

    $(function() {
        if (!noStripeConnectedId && $('[id$="tabs"]').length) {//works only for the Create Payment Method page
            $('[id$="tabs"]').tabs();
            $('.slds-tabs_scoped__item').click(function() {
                ASModule.setActiveTab($(this));
            });
            ASModule.initStripeElements();
            ASModule.overridePageMessages();
        }
    });

    return ASModule;

})(window, document, $j, AcctSeed.ASModule);