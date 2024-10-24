import { LightningElement, api } from 'lwc';
import { LabelService } from "c/utils";

export default class CustomDateCell extends LightningElement {
    @api value;
    @api disabled = false;
    @api editMode = false;
    @api rowId;
    @api colId;

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
    _errors = [];
    labels = LabelService;

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

    handleChange({ detail }) {
        const value = detail.value;
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

    getInputCmp = () => this.template.querySelector('lightning-input');

    getError() {
        const errorMsgs = this._errors
            .filter(e => e.column === this.colId)
            .map(e => e.msg);
        return ( errorMsgs.length > 0 ? errorMsgs[0] : '' );
    }
}