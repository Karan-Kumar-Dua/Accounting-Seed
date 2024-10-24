var $j = jQuery.noConflict();
window.AcctSeed = typeof window.AcctSeed !== 'undefined' ? window.AcctSeed : {};
var AcctSeed = window.AcctSeed;

AcctSeed.ASModule = (function(window, document, $) {
    "use strict";

    var disableButtons = function(label) {
        $('.pbButton > .btn, .pbButtonb > .btn').toggleClass('btnDisabled').prop('disabled', true).val(label);
    };

    var buttonToSpinner = function() {
        $('#spinner').css('display', 'inline');
        $('.toSpinnerOnProcess').css('display', 'none');
    };

    var customBackAction = function() {
        if ((typeof sforce != 'undefined') && sforce && (!!sforce.one)) {
            sforce.one.back(true);
        }
        else {
            backAction();
        }
    };

    var customBackToListAction = function(listViewId, listViewName, scope) {
        if ((typeof sforce != 'undefined') && sforce && (!!sforce.one)) {
            sforce.one.navigateToList(listViewId, null, scope);
        }
        else {
            backAction();
        }
    };

    // Math functions.
    var decimalAdjust = function(type, value, exp) {
        // If the exp is undefined or zero...
        if (typeof exp === 'undefined' || +exp === 0) {
            return Math[type](value);
        }
        value = +value;
        exp = +exp;
        // If the value is not a number or the exp is not an integer...
        if (isNaN(value) || !(typeof exp === 'number' && exp % 1 === 0)) {
            return NaN;
        }
        // Shift
        value = value.toString().split('e');
        value = Math[type](+(value[0] + 'e' + (value[1] ? (+value[1] - exp) : -exp)));
        // Shift back
        value = value.toString().split('e');
        return +(value[0] + 'e' + (value[1] ? (+value[1] + exp) : exp));
    };

    //this is minified version of format function
    var fileSizeFormatter = function(a,b){if(0==a)return"0 Bytes";var c=1024,d=b||2,e=["Bytes","KB","MB","GB","TB","PB","EB","ZB","YB"],f=Math.floor(Math.log(a)/Math.log(c));return parseFloat((a/Math.pow(c,f)).toFixed(d))+" "+e[f]};

    $(function() {
        // Decimal round
        if (!Math.round10) {
            Math.round10 = function(value, exp) {
              return decimalAdjust('round', value, exp);
            };
        }
        // Decimal floor
        if (!Math.floor10) {
            Math.floor10 = function(value, exp) {
              return decimalAdjust('floor', value, exp);
            };
        }
        // Decimal ceil
        if (!Math.ceil10) {
            Math.ceil10 = function(value, exp) {
              return decimalAdjust('ceil', value, exp);
            };
        }
    });

    return {
        disableButtons: disableButtons,
        buttonToSpinner: buttonToSpinner,
        customBackAction: customBackAction,
        customBackToListAction: customBackToListAction,
        fileSizeFormatter: fileSizeFormatter
    };
    
})(window, document, $j);
