import { LightningElement, api } from 'lwc';

export default class XCustomCurrencyCell extends LightningElement {
    @api value;
    @api disabled = false;
    @api editMode = false;
    @api isMultiCurrencyEnabled = false;
    @api currencyCode;
    @api rowId;
    @api colId;
    @api required = false;
    @api valueHideIsoCode =false;
    @api valueParentheses = false;
    @api step = 'any';
    @api minimumFractionDigits = 0;
    @api title = '';

    handleFocus() {
        this.template.activeElement && this.template.activeElement.click();
        this.template.activeElement && this.template.activeElement.click();
    }
    handleChange(evt){
        if((evt.target.value).endsWith('.')){return;}
        let input = this.template.querySelector('lightning-input[data-id="input"]');
        let values = (evt.target.value).split('.');
        if(values.length > 1){
            values[1] = values[1].substring(0,this.minimumFractionDigits);
        }
        input.value = values.join('.');
    }
    handleBlur(evt){        
        this.fireCellBlurEvent(evt.target.value || null);
    }
    fireCellBlurEvent(value) {
        this.dispatchEvent(new CustomEvent('cellblur', {
            composed: true,
            bubbles: true,
            cancelable: true,
            detail: {
                colId: this.colId,
                rowId: this.rowId,
                value: value
            }
        }));
    }
    @api
    reportValidity() {  
        const element = this.template.querySelectorAll('lightning-input');
        return element ? this.showValidityError(element) : true;
    }
    showValidityError(element) {
        let valid = true;
        if(!element.checkValidity()) {
            valid = false;
        } else {
            element.setCustomValidity('');
        }
        element.reportValidity();
        return valid;
    }
}