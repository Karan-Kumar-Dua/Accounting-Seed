import { LightningElement, api } from 'lwc';
import Labels from './labels';
import { LabelService } from 'c/utils';

export default class CustomCurrencyCell extends LightningElement {
    labels = {...Labels, ...LabelService};
    @api value;
    @api disabled = false;
    @api editMode = false;
    @api isMultiCurrencyEnabled = false;
    @api currencyCode;
    @api rowId;
    @api colId;
    @api required = false;

    @api
    get errors() {
        return this._errors;
    }
    set errors(values = []) {
        this._errors = values;
        try {
            this.displayErrors();
        } catch (e) {
            // cmp not yet rendered
        }
    }

    @api
    get valueStyle() {
        return this._valueStyle;
    }
    set valueStyle(val = '') {
        this._valueStyle = val;
    }

    @api
    valueParentheses = false;

    @api
    get valueHideIsoCode() {
        return this._valueHideIsoCode;
    }
    set valueHideIsoCode(val = false) {
        this._valueHideIsoCode = val;
    }

    step = 0.01;
    _errors = [];

    renderedCallback() {
        this.displayErrors();
    }

    displayErrors() {
        if (this.editMode) {
            const error = this.getError();
            const inputCmp = this.getInputCmp();
            inputCmp.setCustomValidity(error);
            inputCmp.reportValidity();
        }
    }

    /*
     * On focus trigger a double click event.
     * This causes the parent datatable to bring focus to 
     * the datatable cell which contains `this`.
     */
    handleFocus() {
        this.template.activeElement.click();
        this.template.activeElement.click();
    }

    handleChange({ detail }) {
        const value = detail.value === '' || isNaN(detail.value) ? 0 : this.floor(detail.value);
        this.fireCellChangeEvent(value);
        this.getInputCmp().reportValidity();
    }

    fireCellChangeEvent(value) {
        this.dispatchEvent(new CustomEvent('cellchange', {
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
    getInputCmp = () => this.template.querySelector('lightning-input');

    getError() {
        const errorMsgs = this._errors
            .filter(e => e.column === this.colId)
            .map(e => e.msg);
        return ( errorMsgs.length > 0 ? errorMsgs[0] : '' );
    }

    floor(value) {
        value = +value;
        let n = Math.floor(value + 'e2') + 'e-2';
        return +n;
    }
 
}